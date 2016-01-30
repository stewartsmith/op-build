################################################################################
#
# skiboot
#
################################################################################

# pje 10/7  - patched to pull in 5.1.6
# pje 11/2  - patched to pull in 5.1.8
# pje 11/16 - patched to pull in 5.1.9
# pje  1/25 - patched to pull in 5.1.12
# pje  1/29 - patched to match what they are using now (ie, updating config.in
#             with the version id to use - 5.1.13)
SKIBOOT_VERSION = $(call qstrip,$(BR2_SKIBOOT_VERSION))

SKIBOOT_SITE = $(call github,open-power,skiboot,$(SKIBOOT_VERSION))
SKIBOOT_INSTALL_IMAGES = YES
SKIBOOT_INSTALL_TARGET = NO

SKIBOOT_MAKE_OPTS += CC="$(TARGET_CC)" LD="$(TARGET_LD)" \
		     AS="$(TARGET_AS)" AR="$(TARGET_AR)" NM="$(TARGET_NM)" \
		     OBJCOPY="$(TARGET_OBJCOPY)" OBJDUMP="$(TARGET_OBJDUMP)" \
		     SIZE="$(TARGET_CROSS)size"

ifeq ($(BR2_TARGET_SKIBOOT_EMBED_PAYLOAD),y)
SKIBOOT_MAKE_OPTS += KERNEL="$(BINARIES_DIR)/$(LINUX_IMAGE_NAME)"

ifeq ($(BR2_TARGET_ROOTFS_INITRAMFS),y)
SKIBOOT_DEPENDENCIES += linux-rebuild-with-initramfs
else
SKIBOOT_DEPENDENCIES += linux
endif

endif

ifeq ($(BR2_SKIBOOT_INSTALL_LIBFLASH),y)
SKIBOOT_INSTALL_STAGING = YES
SKIBOOT_INSTALL_TARGET = YES

define SKIBOOT_INSTALL_STAGING_CMDS
	PREFIX=$(STAGING_DIR)/usr $(MAKE) $(SKIBOOT_MAKE_OPTS) CROSS_COMPILE=$(TARGET_CROSS) -C $(@D)/external/shared install
endef

define SKIBOOT_INSTALL_TARGET_CMDS
	PREFIX=$(TARGET_DIR)/usr $(MAKE) $(SKIBOOT_MAKE_OPTS) CROSS_COMPILE=$(TARGET_CROSS) -C $(@D)/external/shared install-lib
endef
endif

define SKIBOOT_BUILD_CMDS
	$(TARGET_CONFIGURE_OPTS) SKIBOOT_VERSION=`cat $(SKIBOOT_VERSION_FILE)` \
		$(MAKE) $(SKIBOOT_MAKE_OPTS) -C $(@D) all
endef

define SKIBOOT_INSTALL_IMAGES_CMDS
	$(INSTALL) -D -m 755 $(@D)/skiboot.lid $(BINARIES_DIR)
endef

$(eval $(generic-package))
