export TARGET = iphone:clang:latest:12.0
export ARCHS = arm64

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = refresherprobe

refresherprobe_FILES = probe.xm
refresherprobe_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
