ARCHS = arm64
TARGET = iphone:clang:15.6:15.0
INSTALL_TARGET_PROCESSES = WeChat
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = GoutouJunshi
GoutouJunshi_FILES = src/Tweak.m
GoutouJunshi_CFLAGS = -fobjc-arc
GoutouJunshi_FRAMEWORKS = UIKit Foundation
include $(THEOS_MAKE_PATH)/tweak.mk
