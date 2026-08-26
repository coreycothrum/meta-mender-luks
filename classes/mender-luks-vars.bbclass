################################################################################
# mender-luks variables
################################################################################
MENDER/LUKS_BYPASS_REENCRYPT      ??= "1"
MENDER/LUKS_BYPASS_RANDOM_KEY     ??= "1"
MENDER/LUKS_TPM2_READ_CMD         ??= "${@bb.utils.contains('DISTRO_FEATURES', 'tpm2', 'mender-luks-tpm2-util.sh --read', ':', d)}"

MENDER/LUKS_TMP_DIR                 = "/tmp/mender-luks"
MENDER/LUKS_DATA_DIR                = "${MENDER_DATA_PART_MOUNT_LOCATION}/luks"
MENDER/LUKS_HEADER_DIR              = "${MENDER_BOOT_PART_MOUNT_LOCATION}/LUKS"
MENDER/LUKS_HEADER_EXT              = "luks"
MENDER/LUKS_PARTUUID_IS_USED        = "${@bb.utils.contains('MENDER_FEATURES_ENABLE', 'mender-partuuid', 'true', 'false', d)}"

MENDER/LUKS_DM_MAPPER_DIR           = "/dev/mapper"
MENDER/LUKS__DATA__PART___DM_NAME   = "DataPart${MENDER_DATA_PART_NUMBER}"
MENDER/LUKS__SWAP__PART___DM_NAME   = "SwapPart"
MENDER/LUKS_ROOTFS_PART_A_DM_NAME   = "RootfsPart${MENDER_ROOTFS_PART_A_NUMBER}"
MENDER/LUKS_ROOTFS_PART_B_DM_NAME   = "RootfsPart${MENDER_ROOTFS_PART_B_NUMBER}"

MENDER/LUKS_SYSTEMD_INITRD_CREDENTIALS_DIR = "/run/credentials/@initrd"
MENDER/LUKS_SYSTEMD_INITRD_CREDENTIALS_VAR = "cryptsetup.passphrase"
MENDER/LUKS_LEGACY_KEY_FILE         = "${MENDER/LUKS_DATA_DIR}/.key.luks"
MENDER/LUKS_PRIMARY_KEY_SLOT      ??= "0"
MENDER/LUKS_RECOVERY_KEY_SLOT     ??= "7"

# NOTE: these passwords don't do anything w/ the build or initial encryption
# ... they are used to "blacklist" a default password on boot
# ... there are plans to deprecate this functionality
MENDER/LUKS_PASSWORD_DEFAULT        = "password"
# convenience variable to customize post build encrypt script usage print
MENDER/LUKS_PASSWORD              ??= "${MENDER/LUKS_PASSWORD_DEFAULT}"
# not functional; convenience variable to customize post build encrypt script usage print
MENDER/LUKS_PASSWORD_REENCRYPT    ??= "${MENDER/LUKS_PASSWORD}"

MENDER/LUKS_TPM2_DEVICE                  ??= "auto"
MENDER/LUKS_CRYPTSETUP_REENCRYPT_OPTIONS ??= ""
MENDER/LUKS_CRYPTTAB_EXTRA_OPTIONS       ??= "try-empty-password=1,discard"

################################################################################
################################################################################
################################################################################
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
MENDER/LUKS_TPM_PCR_UPDATE_UNLOCK ??= "min"
