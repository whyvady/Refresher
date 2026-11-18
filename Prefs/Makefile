include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = refresherprefs

refresherprefs_FILES = $(wildcard Controllers/*.m)
refresherprefs_INSTALL_PATH = /Library/PreferenceBundles
refresherprefs_PRIVATE_FRAMEWORKS = Preferences
refresherprefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -I../Shared

include $(THEOS_MAKE_PATH)/bundle.mk
