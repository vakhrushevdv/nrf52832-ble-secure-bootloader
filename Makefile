SDK_DIR := nRF5_SDK_17.1.0_ddde560
SDK_URL := https://nsscprodmedia.blob.core.windows.net/prod/software-and-other-downloads/sdks/nrf5/binaries/nrf5_sdk_17.1.0_ddde560.zip

SEGGER_ARM_DIR := arm_segger_embedded_studio_544_linux_x64
SEGGER_ARM_URL := https://dl.a.segger.com/embedded-studio/Setup_EmbeddedStudio_ARM_v544_linux_x64.tar.gz
# https://www.segger.com/downloads/embedded-studio/Setup_EmbeddedStudio_ARM_v544_linux_x64.tar.gz
SEGGER_ARM_INST_DIR := segger_embedded_studio_for_arm_5.44

MICRO_ECC_GIT := https://github.com/kmackay/micro-ecc.git

GCC_ARM_URL := https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-rm/9-2020q2/gcc-arm-none-eabi-9-2020-q2-update-x86_64-linux.tar.bz2
GCC_ARM_DIR := gcc-arm-none-eabi-9-2020-q2-update

OUTPUT := Release

.PHONY: all
all: $(GCC_ARM_DIR) $(SEGGER_ARM_INST_DIR) build

$(SDK_DIR).zip:
	@echo "Downloading SDK archive"
	@curl $(SDK_URL) -o $@ -s

$(SDK_DIR): $(SDK_DIR).zip
	@echo "Extracting SDK"
	@unzip -o -qq $<

$(SEGGER_ARM_DIR).tar.gz:
	@echo "Downloading Segger tools"
	@curl $(SEGGER_ARM_URL) -o $@

$(SEGGER_ARM_DIR): $(SEGGER_ARM_DIR).tar.gz
	@echo "Extracting Segger tools"
	@tar -xzf $<

$(SEGGER_ARM_INST_DIR): $(SEGGER_ARM_DIR)
	@echo "Installing Segger tools"
	@sudo $</install_segger_embedded_studio --accept-license --silent --copy-files-to $@

$(GCC_ARM_DIR).tar.bz2:
	@echo "Downloading GCC ARM tools"
	@curl $(GCC_ARM_URL) -o $@

$(GCC_ARM_DIR): $(GCC_ARM_DIR).tar.bz2
	@echo "Extractiong GCC ARM tools"
	@tar -xjf $<

$(SDK_DIR)/external/micro-ecc/micro-ecc: $(SDK_DIR)
	@echo "Preparing Micro ECC to build"
	@git clone $(MICRO_ECC_GIT) $@

$(SDK_DIR)/external/micro-ecc/nrf52hf_armgcc/armgcc/micro_ecc_lib_nrf52.a: $(SDK_DIR)/external/micro-ecc/micro-ecc
	@echo "Building Micro ECC"
	@sudo chmod +x $(SDK_DIR)/external/micro-ecc/build_all.sh
	@sed -i -e 's/\r$$//' $(SDK_DIR)/external/micro-ecc/build_all.sh
	@cd $(SDK_DIR)/external/micro-ecc/ && GNU_INSTALL_ROOT=$(PWD)/$(GCC_ARM_DIR)/bin/ ./build_all.sh

build-micro-ecc: $(SDK_DIR)/external/micro-ecc/nrf52hf_armgcc/armgcc/micro_ecc_lib_nrf52.a
	@echo "Micro ECC is ready"

build: build-micro-ecc
	@echo "Copying public key"
	@cp dfu_public_key.c $(SDK_DIR)/examples/dfu/ 
	@echo "Building bootloader"
	#add "-verbose -show" to next command line to build the project
	@$(SEGGER_ARM_INST_DIR)/bin/emBuild -config "Release" -project "secure_bootloader_ble_s132_pca10040" $(SDK_DIR)/examples/dfu/secure_bootloader/pca10040_s132_ble/ses/secure_bootloader_ble_s132_pca10040.emProject
	@echo "Creating Release directory"
	@mkdir -p $(OUTPUT)
	@echo "Coping release files to output directory"
	@cp $(SDK_DIR)/examples/dfu/secure_bootloader/pca10040_s132_ble/ses/Output/Release/Exe/secure_bootloader_ble_s132_pca10040.hex $(OUTPUT)/
	@cp $(SDK_DIR)/examples/dfu/secure_bootloader/pca10040_s132_ble/ses/Output/Release/Exe/secure_bootloader_ble_s132_pca10040.elf $(OUTPUT)/
	@cp $(SDK_DIR)/examples/dfu/secure_bootloader/pca10040_s132_ble/ses/Output/Release/Exe/secure_bootloader_ble_s132_pca10040.map $(OUTPUT)/
deps:
	apt install -y zip unzip curl

clean:
	@rm -rf $(SDK_DIR)* $(GCC_ARM_DIR)* $(SEGGER_ARM_DIR)* $(SEGGER_ARM_INST_DIR)* $(OUTPUT)
