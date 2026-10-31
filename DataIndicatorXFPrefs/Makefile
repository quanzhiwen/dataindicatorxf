include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = DataIndicatorXFPrefs

DataIndicatorXFPrefs_FILES = RootController.m
DataIndicatorXFPrefs_INSTALL_PATH = /Library/PreferenceBundles
DataIndicatorXFPrefs_FRAMEWORKS = UIKit
# 链接策略：优先使用 CI 生成的 Preferences 存根框架（$(THEOS)/CrapFrameworks，
# 仅构建期存在，不随包发布），让二进制正常记录对系统私有框架的依赖，
# 避免 dynamic_lookup 在宿主进程尚未加载 Preferences 时 dlopen 失败；
# 本地无存根时回退到运行时动态解析
DIXF_PREFS_STUB = $(THEOS)/CrapFrameworks/Preferences.framework
ifneq ($(wildcard $(DIXF_PREFS_STUB)),)
DataIndicatorXFPrefs_LDFLAGS = -F$(THEOS)/CrapFrameworks -framework Preferences -Wl,-undefined,dynamic_lookup
else
DataIndicatorXFPrefs_LDFLAGS = -Wl,-undefined,dynamic_lookup
endif
DataIndicatorXFPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
