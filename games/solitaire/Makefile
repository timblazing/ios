ARCHS = arm64
# Link against the 16.5 SDK: the 10.3 SDK stubs are rejected by current Xcode linkers. The deployment target stays iOS 10.0.
TARGET = iphone:clang:16.5:10.0
INSTALL_TARGET_PROCESSES = Solitaire

include $(THEOS)/makefiles/common.mk
APPLICATION_NAME = Solitaire
Solitaire_FILES = $(wildcard Application/*.m Application/Game/*.m Application/Scenes/*.m Application/Nodes/*.m Application/UI/*.m)
Solitaire_FRAMEWORKS = UIKit Foundation SpriteKit CoreGraphics QuartzCore
Solitaire_CFLAGS = -fobjc-arc -fno-exceptions -fno-objc-exceptions -Wall -Wextra -Wno-unused-parameter
Solitaire_RESOURCE_DIRS = Resources
Solitaire_INFOPLIST = Resources/Info.plist
Solitaire_CODESIGN_FLAGS = -SResources/Entitlements.plist
include $(THEOS_MAKE_PATH)/application.mk

before-all::
	@scripts/make-icons.sh

after-package::
	@echo "Debian package ready in packages/. Run scripts/package-ipa.sh for an IPA."
