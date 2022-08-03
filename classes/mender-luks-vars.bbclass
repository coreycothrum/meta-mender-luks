################################################################################
# mender-luks variables
################################################################################
MENDER/LUKS_BYPASS_RANDOM_KEY     ??= "0"
MENDER/LUKS_PASSWORD_AGENT_CMD    ??= ":"

MENDER/LUKS_TMP_DIR                 = "/tmp/mender-luks"
MENDER/LUKS_DATA_DIR                = "${MENDER_DATA_PART_MOUNT_LOCATION}/luks"
MENDER/LUKS_HEADER_DIR              = "${MENDER_BOOT_PART_MOUNT_LOCATION}/LUKS"

MENDER/LUKS_ROOTFS_PART_A_HEADER    = "${MENDER/LUKS_HEADER_DIR}/${MENDER/LUKS_ROOTFS_PART_A_HEADER_NAME}"
MENDER/LUKS_ROOTFS_PART_B_HEADER    = "${MENDER/LUKS_HEADER_DIR}/${MENDER/LUKS_ROOTFS_PART_B_HEADER_NAME}"
MENDER/LUKS__DATA__PART___HEADER    = "${MENDER/LUKS_HEADER_DIR}/${MENDER/LUKS__DATA__PART___HEADER_NAME}"

MENDER/LUKS_ROOTFS_PART_A_HEADER_NAME = "${MENDER/LUKS_ROOTFS_PART_A_DM_NAME}.luks"
MENDER/LUKS_ROOTFS_PART_B_HEADER_NAME = "${MENDER/LUKS_ROOTFS_PART_B_DM_NAME}.luks"
MENDER/LUKS__DATA__PART___HEADER_NAME = "${MENDER/LUKS__DATA__PART___DM_NAME}.luks"

MENDER/LUKS_DM_MAPPER_DIR           = "/dev/mapper"
MENDER/LUKS__DATA__PART___DM_NAME   = "DataPart${MENDER_DATA_PART_NUMBER}"
MENDER/LUKS__SWAP__PART___DM_NAME   = "SwapPart"
MENDER/LUKS_ROOTFS_PART_A_DM_NAME   = "RootfsPart${MENDER_ROOTFS_PART_A_NUMBER}"
MENDER/LUKS_ROOTFS_PART_B_DM_NAME   = "RootfsPart${MENDER_ROOTFS_PART_B_NUMBER}"

MENDER/LUKS_SUDO_ENV                = "PATH=$PATH LD_LIBRARY_PATH=$LD_LIBRARY_PATH PSEUDO_UNLOAD=1"
MENDER/LUKS_SUDO_CMD                = "env "PSEUDO_UNLOAD=1" /usr/bin/sudo env "${MENDER/LUKS_SUDO_ENV}""
MENDER/LUKS_DENY_IMAGE_TYPES        = "             \
                                        biosimg.bz2 \
                                        gptimg.bz2  \
                                        sdimg.bz2   \
                                        uefiimg.bz2 \
                                        hddimg      \
                                        wic         \
                                      "

MENDER/LUKS_KEY_FILE                = "${MENDER/LUKS_DATA_DIR}/.key.luks"
MENDER/LUKS_SEAL_DELAY_SECS       ??= "120"
MENDER/LUKS_PRIMARY_KEY_SLOT      ??= "0"
MENDER/LUKS_RECOVERY_KEY_SLOT     ??= "7"
MENDER/LUKS_PASSWORD_DEFAULT        = "password"
MENDER/LUKS_PASSWORD              ??= "${MENDER/LUKS_PASSWORD_DEFAULT}"
MENDER/LUKS_CRYPTSETUP_KEY_SIZE   ??= "512"
MENDER/LUKS_CRYPTSETUP_CIPHER     ??= "aes-xts-plain64"
MENDER/LUKS_CRYPTSETUP_HASH       ??= "sha512"
MENDER/LUKS_CRYPTSETUP_PBKDF      ??= "argon2i"
MENDER/LUKS_CRYPTSETUP_OPTS_BASE    = "--type luks2 --batch-mode"
MENDER/LUKS_CRYPTSETUP_OPTS_SPECS   = "                                                \
                                                   ${MENDER/LUKS_CRYPTSETUP_OPTS_BASE} \
                                        --key-size ${MENDER/LUKS_CRYPTSETUP_KEY_SIZE}  \
                                        --cipher   ${MENDER/LUKS_CRYPTSETUP_CIPHER}    \
                                        --hash     ${MENDER/LUKS_CRYPTSETUP_HASH}      \
                                        --pbkdf    ${MENDER/LUKS_CRYPTSETUP_PBKDF}     \
                                      "
MENDER/LUKS_CRYPTTAB_OPTS         ??= "luks,nofail"

MENDER/LUKS_TPM2TOOLS_TCTI_NAME   ??= "device"
MENDER/LUKS_TPM2TOOLS_DEVICE_FILE ??= "/dev/tpmrm0"

MENDER/LUKS_TPM_KEY_INDEX         ??= "0x81010001"
MENDER/LUKS_TPM_KEY_SIZE_MAX      ??= "128"

MENDER/LUKS_TPM_HIERARCHY         ??= "o"
MENDER/LUKS_TPM_ATTRIBUTES        ??= "noda|adminwithpolicy|fixedparent|fixedtpm"

MENDER/LUKS_TPM_KEY_ALG           ??= "rsa"
MENDER/LUKS_TPM_PCR_ALG           ??= "sha256"
MENDER/LUKS_TPM_HASH_ALG          ??= "sha256"

MENDER/LUKS_TPM_PCR_SET_NONE      ??= "0"
MENDER/LUKS_TPM_PCR_SET_MIN       ??= "0,1"
MENDER/LUKS_TPM_PCR_SET_MAX       ??= "0,1,2,3,4,5"

python () {
  if bb.utils.contains('DISTRO_FEATURES', 'tpm2', True, False, d):
    d.setVar('MENDER/LUKS_PASSWORD_AGENT_CMD', 'mender-luks-tpm2-util.sh --read')
}
