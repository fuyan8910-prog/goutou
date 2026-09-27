ARCHS = arm64
TARGET = iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = WeChat
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = GoutouJunshi
GoutouJunshi_FILES = src/Tweak.xm src/GJModels.m src/GJPreferences.m src/GJMemoryStore.m src/GJWeChatAdapter.m src/GJPromptBuilder.m src/GJDeepSeekClient.m src/GJSettingsViewController.m src/GJAnalysisViewController.m src/GJManager.m
GoutouJunshi_CFLAGS = -fobjc-arc
GoutouJunshi_FRAMEWORKS = UIKit Foundation Security QuartzCore
include $(THEOS_MAKE_PATH)/tweak.mk
