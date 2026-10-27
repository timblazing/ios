ARCHS = arm64
TARGET = iphone:clang:16.5:10.0
INSTALL_TARGET_PROCESSES = T3Mini
include $(THEOS)/makefiles/common.mk
APPLICATION_NAME = T3Mini
T3Mini_FILES = $(wildcard Application/*.m)
T3Mini_FRAMEWORKS = UIKit Foundation WebKit Security
T3Mini_CFLAGS = -fobjc-arc -fno-exceptions -fno-objc-exceptions -Wall -Wextra
T3Mini_RESOURCE_DIRS = Resources
T3Mini_INFOPLIST = Resources/Info.plist
T3Mini_CODESIGN_FLAGS = -SResources/Entitlements.plist
include $(THEOS_MAKE_PATH)/application.mk
before-all::
	@python3 scripts/make-art.py
