#import "RootController.h"
#import "Prefs.h"
#import <notify.h>

// 与 Tweak.x 保持一致
static NSString *const kDIXFDomain   = @"cn.xiumaos.ios";
static NSString *const kDIXFRulesKey = @"rules";
static const char *kDIXFNotify       = "cn.xiumaos.ios.changed";

@implementation RootController

#pragma mark - 规则数组存储（动态条数，无上限）

// 偏好域，PreferenceLoader / PSListController 均以此读写
- (NSString *)bundleIdentifier
{
	return kDIXFDomain;
}

- (NSMutableArray *)storedRules
{
	CFArrayRef stored = CFPreferencesCopyAppValue((__bridge CFStringRef)kDIXFRulesKey,
		(__bridge CFStringRef)kDIXFDomain);
	NSArray *rules = CFBridgingRelease(stored);
	if ([rules isKindOfClass:[NSArray class]])
		return [rules mutableCopy];
	return [NSMutableArray array];
}

- (void)persistRules:(NSArray *)rules
{
	if (rules.count) {
		CFPreferencesSetAppValue((__bridge CFStringRef)kDIXFRulesKey,
			(__bridge CFArrayRef)rules, (__bridge CFStringRef)kDIXFDomain);
	} else {
		CFPreferencesSetAppValue((__bridge CFStringRef)kDIXFRulesKey,
			NULL, (__bridge CFStringRef)kDIXFDomain);
	}
	CFPreferencesAppSynchronize((__bridge CFStringRef)kDIXFDomain);
	notify_post(kDIXFNotify); // SpringBoard 端即时重载，无需 respring
}

#pragma mark - 动态 specifier 构建

- (PSSpecifier *)_groupWithFooter:(NSString *)footer title:(NSString *)title
{
	PSSpecifier *g = [PSSpecifier emptyGroupSpecifier];
	if (title.length)  [g setProperty:title  forKey:@"title"];
	if (footer.length) [g setProperty:footer forKey:@"footerText"];
	return g;
}

- (PSSpecifier *)_switchWithKey:(NSString *)key title:(NSString *)title
{
	PSSpecifier *s = [PSSpecifier preferenceSpecifierNamed:key
		target:self set:NULL get:NULL detail:Nil cell:PSSwitchCell edit:Nil];
	[s setProperty:title forKey:@"title"];
	[s setProperty:kDIXFDomain forKey:@"defaults"];
	[s setProperty:@NO forKey:@"default"];
	return s;
}

- (PSSpecifier *)_ruleSpecifierAtIndex:(NSUInteger)index
{
	PSSpecifier *s = [PSSpecifier preferenceSpecifierNamed:
			[NSString stringWithFormat:@"rule_%lu", (unsigned long)index]
		target:self
		set:@selector(setRuleValue:forSpecifier:)
		get:@selector(ruleValueForSpecifier:)
		detail:Nil cell:PSEditTextCell edit:Nil];
	[s setProperty:[NSString stringWithFormat:@"规则 %lu", (unsigned long)(index + 1)]
		forKey:@"title"];
	[s setProperty:@"例如 4G=5G" forKey:@"placeholder"];
	[s setProperty:@YES forKey:@"noAutoCorrect"];
	return s;
}

- (PSSpecifier *)_buttonNamed:(NSString *)name title:(NSString *)title action:(SEL)action
{
	PSSpecifier *b = [PSSpecifier preferenceSpecifierNamed:name
		target:self set:NULL get:NULL detail:Nil cell:PSButtonCell edit:Nil];
	[b setProperty:title forKey:@"title"];
	b.buttonAction = action;
	return b;
}

- (NSMutableArray *)buildSpecifiers
{
	NSMutableArray *specs = [NSMutableArray array];

	[specs addObject:[self _groupWithFooter
		:@"开启后按下方规则映射状态栏数据标识；关闭开关即恢复显示真实网络类型。规则修改即时生效。"
		title:nil]];
	[specs addObject:[self _switchWithKey:@"enabled" title:@"启用插件"]];

	[specs addObject:[self _groupWithFooter
		:@"格式：原标识=新标识（也支持 -> 或 →），例如 3G=4G、4G=5G。每条规则只在实际显示“原标识”时生效，互不影响，条数不限。常用原标识：E / 3G / 4G / LTE / 5G。留空的行自动忽略。"
		title:@"映射规则"]];

	NSArray *rules = [self storedRules];
	for (NSUInteger i = 0; i < rules.count; i++) {
		[specs addObject:[self _ruleSpecifierAtIndex:i]];
	}

	[specs addObject:[self _buttonNamed:@"addRule" title:@"＋ 添加一条规则"
		action:@selector(addRule:)]];
	[specs addObject:[self _buttonNamed:@"removeLastRule" title:@"－ 删除最后一条规则"
		action:@selector(removeLastRule:)]];
	[specs addObject:[self _buttonNamed:@"clearRules" title:@"清空全部规则"
		action:@selector(clearRules:)]];

	[specs addObject:[self _groupWithFooter
		:@"开启后 App（测速、设备信息等）通过系统接口读取到的网络制式也按同样规则映射。会使插件注入更多进程，如无需要建议保持关闭。"
		title:@"高级"]];
	[specs addObject:[self _switchWithKey:@"enableRadio" title:@"同时修改 App 读取的网络制式"]];

	return specs;
}

- (NSMutableArray *)specifiers
{
	NSMutableArray *specs = [super specifiers];
	if (!specs) {
		specs = [self buildSpecifiers];
		self.specifiers = specs;
	}
	return specs;
}

- (void)rebuildSpecifiers
{
	self.specifiers = [self buildSpecifiers];
	[self reloadSpecifiers];
}

#pragma mark - 规则行的读写（由 PSSpecifier 的 get/set 调用）

static NSUInteger DIXFIndexOfRuleSpecifier(PSSpecifier *specifier)
{
	// identifier 形如 rule_<index>
	NSArray *parts = [specifier.identifier componentsSeparatedByString:@"_"];
	if (parts.count == 2) return [parts[1] unsignedIntegerValue];
	return NSNotFound;
}

- (id)ruleValueForSpecifier:(PSSpecifier *)specifier
{
	NSUInteger idx = DIXFIndexOfRuleSpecifier(specifier);
	NSArray *rules = [self storedRules];
	if (idx < rules.count) return rules[idx];
	return @"";
}

- (void)setRuleValue:(id)value forSpecifier:(PSSpecifier *)specifier
{
	NSUInteger idx = DIXFIndexOfRuleSpecifier(specifier);
	if (idx == NSNotFound) return;

	NSMutableArray *rules = [self storedRules];
	while (rules.count <= idx) [rules addObject:@""];

	NSString *text = [value isKindOfClass:[NSString class]]
		? [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
		: @"";
	rules[idx] = text ?: @"";
	[self persistRules:rules];
}

#pragma mark - 按钮动作

- (void)addRule:(id)sender
{
	NSMutableArray *rules = [self storedRules];
	[rules addObject:@""];
	[self persistRules:rules];
	[self rebuildSpecifiers];
}

- (void)removeLastRule:(id)sender
{
	NSMutableArray *rules = [self storedRules];
	if (!rules.count) return;
	[rules removeLastObject];

	// 尾部连续的空行一并收掉，保持列表紧凑
	while (rules.count &&
		(![rules.lastObject isKindOfClass:[NSString class]] || [(NSString *)rules.lastObject length] == 0)) {
		[rules removeLastObject];
	}

	[self persistRules:rules];
	[self rebuildSpecifiers];
}

- (void)clearRules:(id)sender
{
	[self persistRules:@[]];
	[self rebuildSpecifiers];
}

#pragma mark - 开关变更通知（enabled / enableRadio 走标准存储）

- (void)setValue:(id)value forSpecifier:(PSSpecifier *)specifier
{
	[super setValue:value forSpecifier:specifier];
	notify_post(kDIXFNotify);
}

@end
