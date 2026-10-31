include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = DataIndicatorXFPrefs

DataIndicatorXFPrefs_FILES = RootController.m
DataIndicatorXFPrefs_INSTALL_PATH = /Library/PreferenceBundles
DataIndicatorXFPrefs_FRAMEWORKS = UIKit
# theos 精简 SDK 不含 Preferences 存根库：不在链接期硬链，
# 由 dyld 在加载时解析（宿主进程经 PreferenceLoader 已加载 Preferences 框架）
DataIndicatorXFPrefs_LDFLAGS = -Wl,-undefined,dynamic_lookup
DataIndicatorXFPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
