include $(THEOS)/makefiles/common.mk

TWEAK_NAME = refresher

refresher_FILES = $(wildcard Core/*.m Core/*.xm Icons/*.xm Icons/*.m Dock/*.xm HomeScreen/*.xm StatusBar/*.xm)
refresher_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -I../Shared -ICore
refresher_FRAMEWORKS = UIKit QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk
