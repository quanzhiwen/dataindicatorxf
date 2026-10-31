#ifndef DIXF_PREFS_H
#define DIXF_PREFS_H

// 优先使用 theos SDK 自带的 Preferences 私有框架头文件；
// 若所装 SDK 缺少这些头文件，则使用下面的最小声明（签名与 class-dump 一致，
// 只声明方法、不触碰 ivar 布局，保证运行时安全）。

#if __has_include(<Preferences/PSListController.h>) && __has_include(<Preferences/PSSpecifier.h>)

#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

#else

#import <UIKit/UIKit.h>

@class PSSpecifier;

typedef NS_ENUM(NSInteger, PSCellType) {
	PSGroupCell,
	PSLinkCell,
	PSLinkListCell,
	PSListItemCell,
	PSTitleValueCell,
	PSSliderCell,
	PSSwitchCell,
	PSStaticTextCell,
	PSEditTextCell,
	PSSegmentCell,
	PSGiantIconCell,
	PSGiantCell,
	PSSecureEditTextCell,
	PSButtonCell,
	PSEditTextViewCell,
	PSSpinnerCell
};

@interface PSSpecifier : NSObject
+ (instancetype)emptyGroupSpecifier;
+ (instancetype)preferenceSpecifierNamed:(NSString *)identifier
								  target:(id)target
									 set:(SEL)set
									 get:(SEL)get
								  detail:(Class)detail
									cell:(PSCellType)cellType
									edit:(Class)edit;
@property (nonatomic, retain) id target;
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSString *identifier;
@property (nonatomic) SEL buttonAction;
- (void)setProperty:(id)property forKey:(NSString *)key;
- (id)propertyForKey:(NSString *)key;
@end

@interface PSViewController : UIViewController
@end

@interface PSListController : PSViewController
@property (nonatomic, retain) NSMutableArray *specifiers;
- (void)reloadSpecifiers;
- (void)setValue:(id)value forSpecifier:(PSSpecifier *)specifier;
@end

#endif

#endif /* DIXF_PREFS_H */
