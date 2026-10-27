ARCHS = arm64
TARGET = iphone:clang:16.5:10.0
INSTALL_TARGET_PROCESSES = IPTV

include $(THEOS)/makefiles/common.mk
APPLICATION_NAME = IPTV
IPTV_FILES = $(wildcard Application/*.m Application/*/*.m)
IPTV_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore AVFoundation AVKit CoreMedia
IPTV_CFLAGS = -fobjc-arc -fno-exceptions -fno-objc-exceptions -Wall -Wextra -Wno-unused-parameter
IPTV_RESOURCE_DIRS = Resources
IPTV_INFOPLIST = Resources/Info.plist
include $(THEOS_MAKE_PATH)/application.mk
