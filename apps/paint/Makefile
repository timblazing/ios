ARCHS = arm64
TARGET = iphone:clang:16.5:10.0
INSTALL_TARGET_PROCESSES = Paint

include $(THEOS)/makefiles/common.mk
APPLICATION_NAME = Paint
Paint_FILES = $(wildcard Application/*.m Application/*/*.m)
Paint_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore
Paint_CFLAGS = -fobjc-arc -fno-exceptions -fno-objc-exceptions -Wall -Wextra -Wno-unused-parameter
Paint_RESOURCE_DIRS = Resources
Paint_INFOPLIST = Resources/Info.plist
include $(THEOS_MAKE_PATH)/application.mk

before-all::
	@scripts/make-art.sh
