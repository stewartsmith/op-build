################################################################################
#
# hostboot for POWER8
#
################################################################################
HOSTBOOT_P8_VERSION ?= c35645e2d863e37a4356d141713e082505c51e94

HOSTBOOT_P8_SITE ?= $(call github,open-power,hostboot,$(HOSTBOOT_P8_VERSION))

HOSTBOOT_P8_LICENSE = Apache-2.0
HOSTBOOT_P8_LICENSE_FILES = LICENSE
HOSTBOOT_P8_DEPENDENCIES = host-binutils

HOSTBOOT_P8_INSTALL_IMAGES = YES
HOSTBOOT_P8_INSTALL_TARGET = NO

HOSTBOOT_P8_ENV_VARS=$(TARGET_MAKE_ENV) \
    CONFIG_FILE=$(BR2_EXTERNAL_OP_BUILD_PATH)/configs/hostboot/$(BR2_HOSTBOOT_P8_CONFIG_FILE) \
    OPENPOWER_BUILD=1 CROSS_PREFIX=$(TARGET_CROSS) HOST_PREFIX="" HOST_BINUTILS_DIR=$(HOST_BINUTILS_DIR) \
    HOSTBOOT_P8_VERSION=`cat $(HOSTBOOT_P8_VERSION_FILE)` 

HOSTBOOT_P8_POST_PATCH_HOOKS += HOSTBOOT_P8_APPLY_PATCHES

define HOSTBOOT_P8_BUILD_CMDS
        $(HOSTBOOT_P8_ENV_VARS) bash -c 'cd $(@D) && source ./env.bash && $(MAKE)'
endef

define HOSTBOOT_P8_INSTALL_IMAGES_CMDS
        cd $(@D) && source ./env.bash && $(@D)/src/build/tools/hbDistribute --openpower $(STAGING_DIR)/hostboot_build_images/

	# These steps should really be in the Hostboot Makefiles.
	# They were formerly in update_image.pl in the pnor repo

	# Add SBE/normal headers and inject ECC into HBB (hostboot base) partition binary
	echo "00000000001800000000000008000000000000000007EF80" | xxd -r -ps - $(STAGING_DIR)/hostboot_build_images/sbe.header
	env echo -en VERSION\\0 > $(STAGING_DIR)/hostboot_build_images/hostboot.sha.bin
	sha512sum $(STAGING_DIR)/hostboot_build_images/img/hostboot.bin | awk '{print $1}' | xxd -pr -r >> $(STAGING_DIR)/hostboot_build_images/hostboot.sha.bin
	dd if=$(STAGING_DIR)/hostboot_build_images/hostboot.sha.bin of=$(STAGING_DIR)/hostboot_build_images/secureboot.header ibs=4k conv=sync
	cat $(STAGING_DIR)/hostboot_build_images/sbe.header $(STAGING_DIR)/hostboot_build_images/secureboot.header $(STAGING_DIR)/hostboot_build_images/img/hostboot.bin > $(STAGING_DIR)/hostboot_build_images/hostboot.stage.bin
	dd if=$(STAGING_DIR)/hostboot_build_images/hostboot.stage.bin of=$(STAGING_DIR)/hostboot_build_images/hostboot.header.bin ibs=512k conv=sync

	# Add header and inject ECC into HBI (hostboot extended) partition binary
	env echo -en VERSION\\0 > $(STAGING_DIR)/hostboot_build_images/hostboot_extended.sha.bin
	sha512sum $(STAGING_DIR)/hostboot_build_images/img/hostboot_extended.bin | awk '{print $1}' | xxd -pr -r >> $(STAGING_DIR)/hostboot_build_images/hostboot_extended.sha.bin
	dd if=$(STAGING_DIR)/hostboot_build_images/hostboot_extended.sha.bin of=$(STAGING_DIR)/hostboot_build_images/hostboot.temp.bin ibs=4k conv=sync
	cat $(STAGING_DIR)/hostboot_build_images/img/hostboot_extended.bin >> $(STAGING_DIR)/hostboot_build_images/hostboot.temp.bin
	dd if=$(STAGING_DIR)/hostboot_build_images/hostboot.temp.bin of=$(STAGING_DIR)/hostboot_build_images/hostboot_extended.header.bin ibs=5120k conv=sync

	# Add header and inject ECC into HBRT (hostboot runtime) partition binary
	env echo -en VERSION\\0 > $(STAGING_DIR)/hostboot_build_images/hostboot_runtime.sha.bin
	sha512sum $(STAGING_DIR)/hostboot_build_images/img/hostboot_runtime.bin | awk '{print $1}' | xxd -pr -r >> $(STAGING_DIR)/hostboot_build_images/hostboot_runtime.sha.bin
	dd if=$(STAGING_DIR)/hostboot_build_images/hostboot_runtime.sha.bin of=$(STAGING_DIR)/hostboot_build_images/hostboot.temp.bin ibs=4k conv=sync
	cat $(STAGING_DIR)/hostboot_build_images/img/hostboot_runtime.bin >> $(STAGING_DIR)/hostboot_build_images/hostboot.temp.bin
	dd if=$(STAGING_DIR)/hostboot_build_images/hostboot.temp.bin of=$(STAGING_DIR)/hostboot_build_images/hostboot_runtime.header.bin ibs=3072K conv=sync


endef

$(eval $(generic-package))
