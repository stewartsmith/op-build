################################################################################
#
# openpower_pnor
#
################################################################################

OPENPOWER_PNOR_VERSION ?= d3e41ea1efffc8fa0f96c8239d154dbbe3ee29b4
OPENPOWER_PNOR_SITE ?= $(call github,open-power,pnor,$(OPENPOWER_PNOR_VERSION))

OPENPOWER_PNOR_LICENSE = Apache-2.0
OPENPOWER_PNOR_LICENSE_FILES = LICENSE
OPENPOWER_PNOR_DEPENDENCIES = hostboot-binaries machine-xml skiboot host-openpower-ffs capp-ucode host-libflash

ifeq ($(BR2_OPENPOWER_POWER9),y)
OPENPOWER_PNOR_DEPENDENCIES += hcode
endif

ifeq ($(BR2_PACKAGE_IMA_CATALOG),y)
OPENPOWER_PNOR_DEPENDENCIES += ima-catalog
endif

ifeq ($(BR2_PACKAGE_SKIBOOT_EMBED_PAYLOAD),n)

ifeq ($(BR2_TARGET_ROOTFS_INITRAMFS),y)
OPENPOWER_PNOR_DEPENDENCIES += linux-rebuild-with-initramfs
else
OPENPOWER_PNOR_DEPENDENCIES += linux
endif

endif

ifeq ($(BR2_OPENPOWER_PNOR_XZ_ENABLED),y)
OPENPOWER_PNOR_DEPENDENCIES += host-xz
XZ_ARG=-xz_compression
endif

OPENPOWER_PNOR_DEPENDENCIES += host-sb-signing-utils

ifeq ($(BR2_OPENPOWER_SECUREBOOT_KEY_TRANSITION_TO_DEV),y)
KEY_TRANSITION_ARG=-key_transition imprint
else ifeq ($(BR2_OPENPOWER_SECUREBOOT_KEY_TRANSITION_TO_PROD),y)
KEY_TRANSITION_ARG=-key_transition production
endif

ifneq ($(BR2_OPENPOWER_SECUREBOOT_SIGN_MODE),"")
SIGN_MODE_ARG=-sign_mode $(BR2_OPENPOWER_SECUREBOOT_SIGN_MODE)
endif

ifeq ($(BR2_OPENPOWER_POWER9),y)
    OPENPOWER_RELEASE=p9
else
    OPENPOWER_RELEASE=p8
endif

ifeq ($(BR2_BUILD_PNOR_SQUASHFS),y)
    OPENPOWER_PNOR_DEPENDENCIES += host-openpower-vpnor
endif

OPENPOWER_PNOR_INSTALL_IMAGES = YES
OPENPOWER_PNOR_INSTALL_TARGET = NO

HOSTBOOT_IMAGE_DIR=$(STAGING_DIR)/hostboot_build_images/
HOSTBOOT_BINARY_DIR = $(STAGING_DIR)/hostboot_binaries

HCODE_STAGING_DIR = $(STAGING_DIR)/hcode

SBE_BINARY_DIR = $(STAGING_DIR)/sbe_binaries/
OPENPOWER_PNOR_SCRATCH_DIR = $(STAGING_DIR)/openpower_pnor_scratch/
OPENPOWER_VERSION_DIR = $(STAGING_DIR)/openpower_version
OPENPOWER_MRW_SCRATCH_DIR = $(STAGING_DIR)/openpower_mrw_scratch
OUTPUT_BUILD_DIR = $(STAGING_DIR)/../../../build/
OUTPUT_IMAGES_DIR = $(STAGING_DIR)/../../../images/
HOSTBOOT_BUILD_IMAGES_DIR = $(STAGING_DIR)/../../../staging/hostboot_build_images/

FILES_TO_TAR = $(HOSTBOOT_BUILD_IMAGES_DIR)/* \
               $(OUTPUT_BUILD_DIR)/skiboot-*/skiboot.elf \
               $(OUTPUT_BUILD_DIR)/skiboot-*/skiboot.map \
               $(OUTPUT_BUILD_DIR)/linux-*/.config \
               $(OUTPUT_BUILD_DIR)/linux-*/vmlinux \
               $(OUTPUT_BUILD_DIR)/linux-*/System.map \
               $(OUTPUT_IMAGES_DIR)/zImage.epapr


# Subpackages we want to include in the version info (do not include openpower-pnor)
OPENPOWER_VERSIONED_SUBPACKAGES = skiboot
ifeq ($(BR2_PACKAGE_HOSTBOOT_P8),y)
OPENPOWER_VERSIONED_SUBPACKAGES += hostboot-p8 occ-p8
endif
ifeq ($(BR2_PACKAGE_HOSTBOOT),y)
OPENPOWER_VERSIONED_SUBPACKAGES += hostboot occ
endif
OPENPOWER_VERSIONED_SUBPACKAGES += linux petitboot machine-xml hostboot-binaries capp-ucode
OPENPOWER_PNOR = openpower-pnor

ifeq ($(BR2_OPENPOWER_POWER9),y)
    OPENPOWER_PNOR_DEPENDENCIES += sbe hcode
    OPENPOWER_VERSIONED_SUBPACKAGES += sbe hcode
endif

ifeq ($(BR2_PACKAGE_OCC_P8),y)
    OCC_BIN_FILENAME=$(BR2_OCC_P8_BIN_FILENAME)
else
    OCC_BIN_FILENAME=$(BR2_OCC_BIN_FILENAME)
endif

define OPENPOWER_PNOR_INSTALL_IMAGES_CMDS
        mkdir -p $(OPENPOWER_PNOR_SCRATCH_DIR)
        mkdir -p $(STAGING_DIR)/pnor/

	# Now construct a PNOR exclusively using ffspart

	# Step 1: copy all the partition files over.
	if [ "$(BR2_PACKAGE_HOSTBOOT_P8)" == "y" ]; then \
		cp $(HOSTBOOT_IMAGE_DIR)/hostboot.header.bin $(STAGING_DIR)/pnor/ ; \
		cp $(HOSTBOOT_IMAGE_DIR)/hostboot_extended.header.bin $(STAGING_DIR)/pnor/ ; \
		cp $(HOSTBOOT_IMAGE_DIR)/hostboot_runtime.header.bin $(STAGING_DIR)/pnor/ ; \
		cp $(HOSTBOOT_BINARY_DIR)/$(BR2_HOSTBOOT_BINARY_WINK_FILENAME) $(STAGING_DIR)/pnor/wink.hdr.bin.ecc ; \
		cp $(HOSTBOOT_IMAGE_DIR)/$(BR2_OPENPOWER_TARGETING_BIN_FILENAME) $(STAGING_DIR)/pnor/hostboot_targeting.bin ; \
		cp $(HOSTBOOT_BINARY_DIR)/$(BR2_HOSTBOOT_BINARY_SBE_FILENAME) $(STAGING_DIR)/pnor/sbe.img.ecc ; \
	fi

	if [ -f $(HOSTBOOT_IMAGE_DIR)/$(BR2_OPENPOWER_TARGETING_BIN_FILENAME).protected ]; then \
		cp $(HOSTBOOT_IMAGE_DIR)/$(BR2_OPENPOWER_TARGETING_BIN_FILENAME).protected $(STAGING_DIR)/pnor/hostboot_targeting.bin.protected ; \
		cp $(HOSTBOOT_IMAGE_DIR)/$(BR2_OPENPOWER_TARGETING_BIN_FILENAME).unprotected $(STAGING_DIR)/pnor/hostboot_targeting.bin.unprotected ; \
	fi
	if [ -f $(HOSTBOOT_BINARY_DIR)/$(BR2_HOSTBOOT_BINARY_SBEC_FILENAME) ]; then \
		cp $(HOSTBOOT_BINARY_DIR)/$(BR2_HOSTBOOT_BINARY_SBEC_FILENAME) $(STAGING_DIR)/pnor/sbec.img.ecc ; \
	fi

	# Some signed partitions we still have to get from update_image.pl
	# We pad VERSION to 4k with zeros as per what update_image.pl does
	# We also have to XZ compress skiboot ourselves with worse compression to try
	# to get the same binary as update_image.pl
        if [ "$(BR2_PACKAGE_HOSTBOOT_P8)" == "y" ]; then \
		cp $(BINARIES_DIR)/$(BR2_CAPP_UCODE_BIN_FILENAME) $(STAGING_DIR)/pnor/cappucode.bin ; \
		cp $(BINARIES_DIR)/$(BR2_IMA_CATALOG_FILENAME) $(STAGING_DIR)/pnor/ima_catalog.bin ; \
		xz -fk --stdout --check=crc32 $(BINARIES_DIR)/$(BR2_SKIBOOT_LID_NAME) > $(STAGING_DIR)/pnor/skiboot.lid.xz ; \
		cp $(BINARIES_DIR)/$(LINUX_IMAGE_NAME) $(STAGING_DIR)/pnor/zImage.epapr ; \
		dd if=$(OPENPOWER_PNOR_VERSION_FILE) of=$(STAGING_DIR)/pnor/openpower_pnor_version.bin ibs=4K conv=sync ; \
	fi


	# Step 1.5: emulate the stupid

	# Anyone have *any* idea why we blank (with ecc'd 0xff) 16k of a 20k partition?
	dd if=/dev/zero bs=16K count=1 | tr "\000" "\377" > $(STAGING_DIR)/pnor/guard.bin
	# and 28k of a 32k partition
	dd if=/dev/zero bs=28K count=1 | tr "\000" "\377" > $(STAGING_DIR)/pnor/attr_perm.bin
	# and 8k of 12k partition
	dd if=/dev/zero bs=8K count=1 | tr "\000" "\377" > $(STAGING_DIR)/pnor/firdata.bin

	# and "blank" with ECC'd 0xff 128k of a 144k partition
	# but only on POWER8
	if [ "$(BR2_PACKAGE_HOSTBOOT_P8)" == "y" ]; then \
		dd if=/dev/zero bs=128K count=1 > $(STAGING_DIR)/pnor/secboot.bin ; \
	fi
	# on POWER9 it's instead a full partition of 0xff
	if [ "$(BR2_PACKAGE_HOSTBOOT)" == "y" ]; then \
		dd if=/dev/zero bs=128K count=1 | tr "\000" "\377" > $(STAGING_DIR)/pnor/secboot.bin ; \
	fi

	# and we add ECC to a *non* ecc partition for, ummm, reasons?
	# and only on P8!?
	if [ "$(BR2_PACKAGE_HOSTBOOT_P8)" == "y" ]; then \
		dd if=/dev/zero bs=28K count=1 | tr "\000" "\377" > $(STAGING_DIR)/pnor/attr_tmp.bin ; \
		$(TARGET_MAKE_ENV) ecc --inject $(STAGING_DIR)/pnor/attr_tmp.bin --output $(STAGING_DIR)/pnor/attr_tmp.bin.ecc --p8 ; \
	fi
	# and we get 0xff fill for HDAT on p9
	if [ "$(BR2_PACKAGE_HOSTBOOT)" == "y" ]; then \
		dd if=/dev/zero bs=32K count=1 | tr "\000" "\377" > $(STAGING_DIR)/pnor/hdat.bin ; \
	fi

	# Pad to 0x40000 even though partition is 0x48000 in size?
	dd if=$(HOSTBOOT_BINARY_DIR)/cvpd.bin of=$(STAGING_DIR)/pnor/cvpd.bin ibs=256K conv=sync
	# Pad OCC out on P8 is easy
	if [ "$(BR2_PACKAGE_HOSTBOOT_P8)" == "y" ]; then \
		dd if=$(OCC_STAGING_DIR)/$(OCC_BIN_FILENAME) of=$(STAGING_DIR)/pnor/occ.bin ibs=1M conv=sync ; \
	fi

	# NVRAM is zeros, notably *not* a valid NVRAM partition format
	# but only on POWER8!?!
	if [ "$(BR2_PACKAGE_HOSTBOOT_P8)" == "y" ]; then \
		dd if=/dev/zero bs=512K count=1 of=$(STAGING_DIR)/pnor/nvram.bin ; \
	fi

	# Step 2: build the pnor
	rm -f $(STAGING_DIR)/pnor/ffspart2.pnor
	touch  $(STAGING_DIR)/pnor/ffspart2.pnor
	# Generate it for P8 now, P9 has to come after update_image/create_image for now.
	if [ "$(BR2_PACKAGE_HOSTBOOT_P8)" == "y" ]; then \
		(cd $(STAGING_DIR)/pnor; $(TARGET_MAKE_ENV) ffspart -e -s $(BR2_OPENPOWER_PNOR_BLOCK_SIZE) -c $(BR2_OPENPOWER_PNOR_BLOCK_COUNT) -i $(abspath $(BR2_OPENPOWER_PNOR_CSV_LAYOUT_FILENAME)) -p $(STAGING_DIR)/pnor/ffspart2.pnor) ; \
	fi

	if [ "$(BR2_OPENPOWER_PNOR_OLD_METHOD)" == "y" ]; then \
        $(TARGET_MAKE_ENV) $(@D)/update_image.pl \
            -release  $(OPENPOWER_RELEASE) \
            -op_target_dir $(HOSTBOOT_IMAGE_DIR) \
            -hb_image_dir $(HOSTBOOT_IMAGE_DIR) \
            -scratch_dir $(OPENPOWER_PNOR_SCRATCH_DIR) \
            -hb_binary_dir $(HOSTBOOT_BINARY_DIR) \
            -hcode_dir $(HCODE_STAGING_DIR) \
            -targeting_binary_filename $(BR2_OPENPOWER_TARGETING_ECC_FILENAME) \
            -targeting_binary_source $(BR2_OPENPOWER_TARGETING_BIN_FILENAME) \
            -targeting_RO_binary_filename $(BR2_OPENPOWER_TARGETING_ECC_FILENAME).protected \
            -targeting_RO_binary_source $(BR2_OPENPOWER_TARGETING_BIN_FILENAME).protected \
            -targeting_RW_binary_filename $(BR2_OPENPOWER_TARGETING_ECC_FILENAME).unprotected \
            -targeting_RW_binary_source $(BR2_OPENPOWER_TARGETING_BIN_FILENAME).unprotected \
            -sbe_binary_filename $(BR2_HOSTBOOT_BINARY_SBE_FILENAME) \
            -sbe_binary_dir $(SBE_BINARY_DIR) \
            -sbec_binary_filename $(BR2_HOSTBOOT_BINARY_SBEC_FILENAME) \
            -wink_binary_filename $(BR2_HOSTBOOT_BINARY_WINK_FILENAME) \
            -occ_binary_filename $(OCC_STAGING_DIR)/$(OCC_BIN_FILENAME) \
            -capp_binary_filename $(BINARIES_DIR)/$(BR2_CAPP_UCODE_BIN_FILENAME) \
            -ima_catalog_binary_filename $(BINARIES_DIR)/$(BR2_IMA_CATALOG_FILENAME) \
            -openpower_version_filename $(OPENPOWER_PNOR_VERSION_FILE) \
            -wof_binary_filename $(OPENPOWER_MRW_SCRATCH_DIR)/$(BR2_WOFDATA_FILENAME) \
            -memd_binary_filename $(OPENPOWER_MRW_SCRATCH_DIR)/$(BR2_MEMDDATA_FILENAME) \
            -payload $(BINARIES_DIR)/$(BR2_SKIBOOT_LID_NAME) \
            -payload_filename $(BR2_SKIBOOT_LID_XZ_NAME) \
            -binary_dir $(BINARIES_DIR) \
            -bootkernel_filename $(LINUX_IMAGE_NAME) \
            -pnor_layout $(@D)/"$(OPENPOWER_RELEASE)"Layouts/$(BR2_OPENPOWER_PNOR_XML_LAYOUT_FILENAME) \
            $(XZ_ARG) $(KEY_TRANSITION_ARG) $(SIGN_MODE_ARG) ; \
	fi
	if [ "$(BR2_OPENPOWER_PNOR_OLD_METHOD)" == "y" ]; then \
        $(TARGET_MAKE_ENV) $(@D)/create_pnor_image.pl \
            -release $(OPENPOWER_RELEASE) \
            -xml_layout_file $(@D)/"$(OPENPOWER_RELEASE)"Layouts/$(BR2_OPENPOWER_PNOR_XML_LAYOUT_FILENAME) \
            -pnor_filename $(STAGING_DIR)/pnor/$(BR2_OPENPOWER_PNOR_FILENAME) \
            -hb_image_dir $(HOSTBOOT_IMAGE_DIR) \
            -scratch_dir $(OPENPOWER_PNOR_SCRATCH_DIR) \
            -outdir $(STAGING_DIR)/pnor/ \
            -payload $(OPENPOWER_PNOR_SCRATCH_DIR)/$(BR2_SKIBOOT_LID_XZ_NAME) \
            -bootkernel $(OPENPOWER_PNOR_SCRATCH_DIR)/$(LINUX_IMAGE_NAME) \
            -sbe_binary_filename $(BR2_HOSTBOOT_BINARY_SBE_FILENAME) \
            -sbec_binary_filename $(BR2_HOSTBOOT_BINARY_SBEC_FILENAME) \
            -wink_binary_filename $(BR2_HOSTBOOT_BINARY_WINK_FILENAME) \
            -occ_binary_filename $(OCC_STAGING_DIR)/$(OCC_BIN_FILENAME) \
            -targeting_binary_filename $(BR2_OPENPOWER_TARGETING_ECC_FILENAME) \
            -targeting_RO_binary_filename $(BR2_OPENPOWER_TARGETING_ECC_FILENAME).protected \
            -targeting_RW_binary_filename $(BR2_OPENPOWER_TARGETING_ECC_FILENAME).unprotected \
            -wofdata_binary_filename $(OPENPOWER_PNOR_SCRATCH_DIR)/$(BR2_WOFDATA_BINARY_FILENAME) \
            -memddata_binary_filename $(OPENPOWER_PNOR_SCRATCH_DIR)/$(BR2_MEMDDATA_BINARY_FILENAME) \
            -openpower_version_filename $(OPENPOWER_PNOR_SCRATCH_DIR)/openpower_pnor_version.bin ;\
	fi

        if [ "$(BR2_PACKAGE_HOSTBOOT)" == "y" ]; then \
		cp $(OPENPOWER_PNOR_SCRATCH_DIR)/cappucode.bin.ecc $(STAGING_DIR)/pnor/cappucode.bin.ecc ; \
		cp $(OPENPOWER_PNOR_SCRATCH_DIR)/ima_catalog.bin.ecc $(STAGING_DIR)/pnor/ima_catalog.bin.ecc ; \
		cp $(OPENPOWER_PNOR_SCRATCH_DIR)/$(BR2_SKIBOOT_LID_XZ_NAME) $(STAGING_DIR)/pnor/skiboot.lid.xz.stb ; \
		cp $(OPENPOWER_PNOR_SCRATCH_DIR)/$(LINUX_IMAGE_NAME) $(STAGING_DIR)/pnor/zImage.epapr.stb ; \
		cp $(OPENPOWER_PNOR_SCRATCH_DIR)/openpower_pnor_version.bin $(STAGING_DIR)/pnor/openpower_pnor_version.bin ; \
	fi
	# We don't (yet) do the STB header
	if [ "$(BR2_PACKAGE_HOSTBOOT)" == "y" ]; then \
		cp $(OPENPOWER_PNOR_SCRATCH_DIR)/hostboot.header.bin.ecc $(STAGING_DIR)/pnor/ ; \
		cp $(OPENPOWER_PNOR_SCRATCH_DIR)/hostboot_extended.header.bin.ecc $(STAGING_DIR)/pnor/ ; \
		cp $(OPENPOWER_PNOR_SCRATCH_DIR)/hostboot_runtime.header.bin.ecc $(STAGING_DIR)/pnor/ ; \
	fi

	# POWER9 only (or, rather, not p8)
        if [ "$(BR2_PACKAGE_HOSTBOOT)" == "y" ]; then \
		cp $(OPENPOWER_PNOR_SCRATCH_DIR)/hbbl.bin.ecc $(STAGING_DIR)/pnor/hbbl.bin.ecc; \
		$(TARGET_MAKE_ENV) python $(SBE_BINARY_DIR)/sbeOpDistribute.py --install \
			--buildSbePart $(HOSTBOOT_IMAGE_DIR)/buildSbePart.pl \
			--hw_ref_image $(HCODE_STAGING_DIR)/p9n.ref_image.bin \
			--sbe_binary_filename $(BR2_HOSTBOOT_BINARY_SBE_FILENAME) \
			--scratch_dir $(OPENPOWER_PNOR_SCRATCH_DIR) \
			--sbe_binary_dir $(SBE_BINARY_DIR) ; \
		cp $(OPENPOWER_PNOR_SCRATCH_DIR)/SBKT.bin $(STAGING_DIR)/pnor/SBKT.bin.ecc ; \
		cp $(OPENPOWER_PNOR_SCRATCH_DIR)/$(BR2_WOFDATA_BINARY_FILENAME) $(STAGING_DIR)/pnor/wofdata.bin.ecc ; \
		cp $(OPENPOWER_PNOR_SCRATCH_DIR)/$(BR2_MEMDDATA_BINARY_FILENAME) $(STAGING_DIR)/pnor/memd_extra_data.bin.ecc ; \
		cp $(OPENPOWER_PNOR_SCRATCH_DIR)/$(BR2_HOSTBOOT_BINARY_WINK_FILENAME) $(STAGING_DIR)/pnor/hcode.bin.ecc ; \
		cp $(OPENPOWER_PNOR_SCRATCH_DIR)/$(BR2_OPENPOWER_TARGETING_BIN_FILENAME).ecc $(STAGING_DIR)/pnor/hostboot_targeting.bin.ecc ; \
	fi

	# On P9 we don't need to pad OCC, but we do have the secboot header
	if [ "$(BR2_PACKAGE_HOSTBOOT)" == "y" ]; then \
		cp $(OCC_STAGING_DIR)/$(OCC_BIN_FILENAME).ecc $(STAGING_DIR)/pnor/occ.bin.header.ecc ; \
	fi

	if [ "$(BR2_PACKAGE_HOSTBOOT)" == "y" ]; then \
		(cd $(STAGING_DIR)/pnor; $(TARGET_MAKE_ENV) ffspart -e -s $(BR2_OPENPOWER_PNOR_BLOCK_SIZE) -c $(BR2_OPENPOWER_PNOR_BLOCK_COUNT) -i $(abspath $(BR2_OPENPOWER_PNOR_CSV_LAYOUT_FILENAME)) -p $(STAGING_DIR)/pnor/ffspart2.pnor) ; \
	fi

	if [ "$(BR2_OPENPOWER_PNOR_OLD_METHOD)" == "y" ]; then \
	        $(INSTALL) $(STAGING_DIR)/pnor/$(BR2_OPENPOWER_PNOR_FILENAME) $(BINARIES_DIR) ; \
	else \
		cp $(STAGING_DIR)/pnor/ffspart2.pnor $(STAGING_DIR)/pnor/$(BR2_OPENPOWER_PNOR_FILENAME) ; \
		$(INSTALL) $(STAGING_DIR)/pnor/ffspart2.pnor $(BINARIES_DIR)/$(BR2_OPENPOWER_PNOR_FILENAME) ; \
	fi

	if [ "$(BR2_OPENPOWER_PNOR_OLD_METHOD)" == "y" ]; then \
		if [ "$(BR2_PACKAGE_HOSTBOOT_P8)" == "y" ]; then \
			$(TARGET_MAKE_ENV) ../openpower/scripts/pnordiff.sh $(STAGING_DIR)/pnor/$(BR2_OPENPOWER_PNOR_FILENAME) $(STAGING_DIR)/pnor/ffspart.pnor ; \
		fi ; \
		$(TARGET_MAKE_ENV) ../openpower/scripts/pnordiff.sh $(STAGING_DIR)/pnor/$(BR2_OPENPOWER_PNOR_FILENAME) $(STAGING_DIR)/pnor/ffspart2.pnor ; \
	fi


        # if this config has an UPDATE_FILENAME defined, create a 32M (1/2 size)
        # image that only updates the non-golden side
        if [ "$(BR2_OPENPOWER_PNOR_UPDATE_FILENAME)" != "" ]; then \
            dd if=$(STAGING_DIR)/pnor/$(BR2_OPENPOWER_PNOR_FILENAME) of=$(STAGING_DIR)/pnor/$(BR2_OPENPOWER_PNOR_UPDATE_FILENAME) bs=32M count=1; \
            $(INSTALL) $(STAGING_DIR)/pnor/$(BR2_OPENPOWER_PNOR_UPDATE_FILENAME) $(BINARIES_DIR); \
        fi

        # If this is a VPNOR system, run the generate-squashfs command and
        # create a tarball
        if [ "$(BR2_BUILD_PNOR_SQUASHFS)" == "y" ]; then \
            PATH=$(HOST_DIR)/usr/bin:$(PATH) $(HOST_DIR)/usr/bin/generate-squashfs -f $(STAGING_DIR)/pnor/$(BR2_OPENPOWER_PNOR_FILENAME).squashfs.tar $(STAGING_DIR)/pnor/$(BR2_OPENPOWER_PNOR_FILENAME) -s; \
            $(INSTALL) $(STAGING_DIR)/pnor/$(BR2_OPENPOWER_PNOR_FILENAME).squashfs.tar $(BINARIES_DIR); \
        fi

	#Create Debug Tarball
	mkdir -p $(STAGING_DIR)/pnor/host_fw_debug_tarball_files/
	cp -r $(FILES_TO_TAR) $(STAGING_DIR)/pnor/host_fw_debug_tarball_files/
	tar -zcvf $(OUTPUT_IMAGES_DIR)/host_fw_debug.tar -C $(STAGING_DIR)/pnor/host_fw_debug_tarball_files/  .

endef

$(eval $(generic-package))
# Generate openPOWER pnor version string by combining subpackage version string files
$(eval $(call OPENPOWER_VERSION,$(OPENPOWER_PNOR)))
