ARCHS = arm64
TARGET = iphone:clang:16.5:10.0
INSTALL_TARGET_PROCESSES = RentTrivia

include $(THEOS)/makefiles/common.mk
APPLICATION_NAME = RentTrivia
RentTrivia_FILES = $(wildcard Application/*.m Application/*/*.m)
RentTrivia_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore AVFoundation AVKit CoreMedia
RentTrivia_CFLAGS = -fobjc-arc -fno-exceptions -fno-objc-exceptions -Wall -Wextra -Wno-unused-parameter
RentTrivia_RESOURCE_DIRS = Resources
RentTrivia_INFOPLIST = Resources/Info.plist
include $(THEOS_MAKE_PATH)/application.mk

before-all::
	@scripts/make-art.py
