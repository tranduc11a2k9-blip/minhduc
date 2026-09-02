export THEOS ?= /home/tduck/theos

TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FilzaApplySandboxExt

# --- Tweak + sandbox escape + platformize ---
FilzaApplySandboxExt_FILES = Tweak.m sandbox_escape.m apfs_own.m platformize.m

# --- kexploit ---
FilzaApplySandboxExt_FILES += kexploit/kexploit_opa334.m kexploit/krw.m kexploit/kutils.m kexploit/offsets.m kexploit/vnode.m

# --- utils ---
FilzaApplySandboxExt_FILES += utils/file.c utils/hexdump.c utils/process.c

# --- kpf ---
FilzaApplySandboxExt_FILES += kpf/patchfinder.m

# --- XPF ---
FilzaApplySandboxExt_FILES += XPF/src/xpf.c XPF/src/common.c XPF/src/decompress.c XPF/src/bad_recovery.c XPF/src/non_ppl.c XPF/src/ppl.c

# --- ChOma ---
FilzaApplySandboxExt_FILES += XPF/external/ChOma/src/arm64.c XPF/external/ChOma/src/Base64.c XPF/external/ChOma/src/BufferedStream.c XPF/external/ChOma/src/CodeDirectory.c XPF/external/ChOma/src/CSBlob.c XPF/external/ChOma/src/DER.c XPF/external/ChOma/src/DyldSharedCache.c XPF/external/ChOma/src/Entitlements.c XPF/external/ChOma/src/Fat.c XPF/external/ChOma/src/FileStream.c XPF/external/ChOma/src/Host.c XPF/external/ChOma/src/MachO.c XPF/external/ChOma/src/MachOLoadCommand.c XPF/external/ChOma/src/MemoryStream.c XPF/external/ChOma/src/PatchFinder.c XPF/external/ChOma/src/PatchFinder_arm64.c XPF/external/ChOma/src/Util.c

# --- ESP (Fl0rk-style: in-app HUD + kernel-rw memory provider) ---
FilzaApplySandboxExt_FILES += esp/DSMemory.m
FilzaApplySandboxExt_FILES += $(wildcard esp/esp/*.mm) $(wildcard esp/esp/*.cpp)
FilzaApplySandboxExt_FILES += $(wildcard esp/esp/espdraw/*)

# --- Flags ---
FilzaApplySandboxExt_CFLAGS = -I$(PWD) -I$(PWD)/XPF/src -I$(PWD)/XPF/external/ChOma/include \
    -I$(PWD)/esp -I$(PWD)/esp/esp -I$(PWD)/esp/esp/espdraw \
    -I$(PWD)/utils/xpc -I$(PWD)/utils/fileport \
    -Wno-unused-function -Wno-unused-variable \
    -Wno-incompatible-pointer-types -Wno-incompatible-pointer-types-discards-qualifiers \
    -Wno-deprecated-declarations -Wno-nonportable-include-path -Wno-format

FilzaApplySandboxExt_CCFLAGS = -std=c++17 $(FilzaApplySandboxExt_CFLAGS)
FilzaApplySandboxExt_OBJCFLAGS = $(FilzaApplySandboxExt_CFLAGS)
FilzaApplySandboxExt_OBJCCFLAGS = -std=c++17 $(FilzaApplySandboxExt_CFLAGS)

FilzaApplySandboxExt_FRAMEWORKS = UIKit Foundation IOKit CoreFoundation CoreGraphics QuartzCore CoreText
FilzaApplySandboxExt_PRIVATE_FRAMEWORKS = IOSurface BackBoardServices GraphicsServices SpringBoardServices
FilzaApplySandboxExt_LIBRARIES = z sandbox
FilzaApplySandboxExt_LDFLAGS += JRMemory.framework/JRMemory

FilzaApplySandboxExt_INSTALL_TARGET_PROCESSES = Filza

include $(THEOS_MAKE_PATH)/tweak.mk
