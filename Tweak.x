// DataIndicatorXF - 状态栏数据标识自定义映射插件
// 支持 iOS 16 ~ iOS 18（rootless / roothide / rootful）
//
// 原理：
//   1. 状态栏网络标识（E / 3G / 4G / 5G / LTE）的数据源是 SpringBoard 进程中的
//      CCDataIndicatorData 对象，其 -displayString 即最终显示的文本。
//      Hook 该 getter，按用户配置的"多条映射规则"把原始文本换成目标文本。
//      例如规则 "4G=5G" 只影响当前显示 4G 的时候，显示 3G 时不受影响，
//      这正是与"电话助手"（把所有标识强制改成同一个）的区别。
//   2. 可选：同时 Hook CTRadioAccessHelper 的网络类型接口，
//      让 App（测速、装机助手等）读取到的制式也跟随映射规则变化。

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString *const kDIXFPrefsDomain = @"cn.xiumaos.ios";
static CFStringRef const kDIXFPrefsChanged = CFSTR("cn.xiumaos.ios.changed");
static NSString *const kDIXFRulesKey = @"rules";      // 新格式：字符串数组 ["3G=4G", ...]
static const NSUInteger kDIXFLegacyMaxRules = 8;      // 旧版 rule_1..rule_8 兼容

static BOOL gDIXFEnabled             = NO;   // 主开关
static BOOL gDIXFRadioEnabled        = NO;   // 是否同时修改 App 读取到的制式
static NSDictionary<NSString *, NSString *> *gDIXFDisplayMap = nil; // "4G" -> "5G"

#pragma mark - 制式 <-> 显示文本 对照表

// CTRadioAccessTechnology 常量值与其符号名一致，直接写字符串避免依赖私有头文件
static NSDictionary<NSString *, NSString *> *kDIXFTechToToken;  // 制式 -> 显示标识
static NSDictionary<NSString *, NSString *> *kDIXFTokenToTech;  // 显示标识 -> 制式

static void DIXFBuildTechMaps(void)
{
	kDIXFTechToToken = @{
		@"CTRadioAccessTechnologyGPRS":              @"E",
		@"CTRadioAccessTechnologyEdge":              @"E",
		@"CTRadioAccessTechnologyCDMA1x":            @"1X",
		@"CTRadioAccessTechnologyWCDMA":             @"3G",
		@"CTRadioAccessTechnologyHSDPA":             @"3G",
		@"CTRadioAccessTechnologyHSUPA":             @"3G",
		@"CTRadioAccessTechnologyCDMAEVDORev0":      @"3G",
		@"CTRadioAccessTechnologyCDMAEVDORevA":      @"3G",
		@"CTRadioAccessTechnologyCDMAEVDORevB":      @"3G",
		@"CTRadioAccessTechnologyeHRPD":             @"3G",
		@"CTRadioAccessTechnologyHRPD":              @"3G",
		@"CTRadioAccessTechnologyLTE":               @"4G",
		@"CTRadioAccessTechnologyNRNSA":             @"5G",
		@"CTRadioAccessTechnologyNR":                @"5G",
	};

	kDIXFTokenToTech = @{
		@"E":    @"CTRadioAccessTechnologyEdge",
		@"2G":   @"CTRadioAccessTechnologyEdge",
		@"1X":   @"CTRadioAccessTechnologyCDMA1x",
		@"3G":   @"CTRadioAccessTechnologyHSDPA",
		@"H":    @"CTRadioAccessTechnologyHSUPA",
		@"4G":   @"CTRadioAccessTechnologyLTE",
		@"LTE":  @"CTRadioAccessTechnologyLTE",
		@"5G":   @"CTRadioAccessTechnologyNR",
		@"5G+":  @"CTRadioAccessTechnologyNR",
	};
}

#pragma mark - 偏好读取（CFPreferences，rootless/rootful 路径均由 cfprefsd 处理）

static id DIXFCopyPrefValue(NSString *key)
{
	CFPropertyListRef value = CFPreferencesCopyValue((__bridge CFStringRef)key,
		(__bridge CFStringRef)kDIXFPrefsDomain,
		kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	return CFBridgingRelease(value);
}

static BOOL DIXFCopyPrefBool(NSString *key, BOOL fallback)
{
	id value = DIXFCopyPrefValue(key);
	if ([value isKindOfClass:[NSNumber class]]) return [value boolValue];
	return fallback;
}

static NSString *DIXFTrimUpper(NSString *s)
{
	if (![s isKindOfClass:[NSString class]] || !s.length) return nil;
	s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	return s.length ? s.uppercaseString : nil;
}

// 解析 "3G=4G" / "4G->5G" / "4G→5G" 形式的规则并写入映射表
static void DIXFParseRule(NSMutableDictionary *map, NSString *rule)
{
	if (![rule isKindOfClass:[NSString class]] || !rule.length) return;

	NSString *from = nil, *to = nil;
	for (NSString *sep in @[ @"→", @"->", @"=", @"：", @":" ]) {
		NSRange r = [rule rangeOfString:sep];
		if (r.location != NSNotFound) {
			from = DIXFTrimUpper([rule substringToIndex:r.location]);
			to   = DIXFTrimUpper([rule substringFromIndex:NSMaxRange(r)]);
			break;
		}
	}
	if (!from.length || !to.length) return;
	if ([from isEqualToString:to]) return; // 原样则跳过
	map[from] = to;
}

static void DIXFReloadPreferences(void)
{
	gDIXFEnabled      = DIXFCopyPrefBool(@"enabled", NO);
	gDIXFRadioEnabled = DIXFCopyPrefBool(@"enableRadio", NO);

	NSMutableDictionary *map = [NSMutableDictionary dictionary];

	// 新格式：rules 字符串数组，条数不限
	id rulesValue = DIXFCopyPrefValue(kDIXFRulesKey);
	if ([rulesValue isKindOfClass:[NSArray class]]) {
		for (NSString *rule in (NSArray *)rulesValue) {
			DIXFParseRule(map, rule);
		}
	}

	// 兼容旧版 rule_1..rule_8 单项存储
	for (NSUInteger i = 1; i <= kDIXFLegacyMaxRules; i++) {
		DIXFParseRule(map, DIXFCopyPrefValue([NSString stringWithFormat:@"rule_%lu", (unsigned long)i]));
	}

	gDIXFDisplayMap = map;
	NSLog(@"[DataIndicatorXF] reload enabled=%d radio=%d rules=%@", gDIXFEnabled, gDIXFRadioEnabled, gDIXFDisplayMap);
}

// 按当前显示文本查映射结果
static NSString *DIXFMapDisplayString(NSString *original)
{
	if (!gDIXFEnabled || !gDIXFDisplayMap.count) return nil;
	NSString *token = DIXFTrimUpper(original);
	if (!token) return nil;
	NSString *target = gDIXFDisplayMap[token];
	return [target isEqualToString:token] ? nil : target;
}

// 制式字符串按同样规则映射
static NSString *DIXFMapRadioTech(NSString *tech)
{
	if (!gDIXFEnabled || !gDIXFRadioEnabled || !gDIXFDisplayMap.count) return nil;
	if (![tech isKindOfClass:[NSString class]] || !tech.length) return nil;

	NSString *token = kDIXFTechToToken[tech];
	if (!token) {
		// 兼容未知/新增制式：CTRadioAccessTechnologyNR_xxx 等按前缀猜
		if ([tech hasSuffix:@"NR"] || [tech containsString:@"NR_SA"] || [tech containsString:@"NRNSA"]) token = @"5G";
		else if ([tech containsString:@"LTE"]) token = @"4G";
		else if ([tech containsString:@"HSPAP"] || [tech containsString:@"HSDPA"] || [tech containsString:@"UMTS"]) token = @"3G";
	}
	if (!token) return nil;

	NSString *targetToken = gDIXFDisplayMap[token];
	if (!targetToken) return nil;
	return kDIXFTokenToTech[targetToken];
}

#pragma mark - Hooks

// 组 1：SpringBoard 状态栏显示（CCDataIndicatorData 只存在于 SpringBoard 进程）
%group DIXFDisplay

%hook CCDataIndicatorData

- (id)displayString
{
	NSString *original = %orig;
	NSString *mapped = DIXFMapDisplayString(original);
	return mapped ?: original;
}

%end

%end

// 组 2：让 App 读到的无线制式跟随映射（注入所有加载 CellularTelephony 的进程，
//        默认关闭，运行时开关即时生效，不需要重装钩子）
%group DIXFRadio

%hook CTRadioAccessHelper

- (id)currentRadioAccessTechnology
{
	NSString *original = %orig;
	NSString *mapped = DIXFMapRadioTech(original);
	return mapped ?: original;
}

- (id)radioAccessTechnology
{
	NSString *original = %orig;
	NSString *mapped = DIXFMapRadioTech(original);
	return mapped ?: original;
}

%end

%end

#pragma mark - Init

static void DIXFPrefsChanged(CFNotificationCenterRef center, void *observer,
	CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	DIXFReloadPreferences();
}

%ctor
{
	@autoreleasepool {
		DIXFBuildTechMaps();
		DIXFReloadPreferences();

		// Settings 修改后立即生效，无需重新注销/重启
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
			NULL, DIXFPrefsChanged,
			kDIXFPrefsChanged, NULL,
			CFNotificationSuspensionBehaviorDeliverImmediately);

		if (%c(CCDataIndicatorData)) %init(DIXFDisplay);
		if (%c(CTRadioAccessHelper)) %init(DIXFRadio);
	}
}
