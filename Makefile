ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:16.0

# 默认 rootless（Dopamine / palera1n rootless / strix / roothide 用 roothide）
# rootful 老越狱可命令行覆盖: make THEOS_PACKAGE_SCHEME=
THEOS_PACKAGE_SCHEME ?= rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DataIndicatorXF

DataIndicatorXF_FILES = Tweak.x
DataIndicatorXF_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
DataIndicatorXF_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk

# Settings 偏好设置插件(bundle)
SUBPROJECTS += DataIndicatorXFPrefs
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "uicache -a; killall -w SpringBoard || true"
