export TARGET = iphone:clang:latest:12.0
export ARCHS = arm64

INSTALL_TARGET_PROCESSES = SpringBoard Preferences

include $(THEOS)/makefiles/common.mk

SUBPROJECTS = Tweak Prefs

include $(THEOS_MAKE_PATH)/aggregate.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences $(THEOS_STAGING_DIR)/Library/Refresher$(ECHO_END)
	$(ECHO_NOTHING)cp Prefs/entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/refresher.plist$(ECHO_END)
	$(ECHO_NOTHING)cp -R Assets/Icons $(THEOS_STAGING_DIR)/Library/Refresher/$(ECHO_END)
