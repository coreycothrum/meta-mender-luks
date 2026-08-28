################################################################################
# mender-luks variables
################################################################################
MENDER/LUKS_PASSWORD                                      ??= "password"
MENDER/LUKS_CRYPTENROLL_PASSWORD_FORBID_EMPTY             ??= "0"
MENDER/LUKS_CRYPTENROLL_PASSWORD_RANDOMIZE_ON_INIT        ??= "0"
MENDER/LUKS_CRYPTENROLL_TPM2_PCRS___SEALED                ??= "7+11"
MENDER/LUKS_CRYPTENROLL_TPM2_PCRS_UNSEALED                ??= ""
MENDER/LUKS_DISTRO_FEATURES_CONTAIN_TPM2                    = "${@bb.utils.contains('DISTRO_FEATURES', 'tpm2', '1', '0', d)}"

MENDER/LUKS_TPM2_DEVICE                                   ??= "auto"
MENDER/LUKS_CRYPTSETUP_REENCRYPT_OPTIONS                  ??= ""
MENDER/LUKS_CRYPTTAB_EXTRA_OPTIONS                        ??= "try-empty-password=1,discard"

MENDER/LUKS_DATA_DIR                                        = "${MENDER_DATA_PART_MOUNT_LOCATION}/luks"
MENDER/LUKS_HEADER_DIR                                      = "${MENDER_BOOT_PART_MOUNT_LOCATION}/LUKS"
MENDER/LUKS_HEADER_EXT                                      = "luks"
MENDER/LUKS_RECOVERY_EXT                                    = "recovery"
MENDER/LUKS_LEGACY_KEY_FILE                                 = "${MENDER/LUKS_DATA_DIR}/.key.luks"
MENDER/LUKS_ROOT_CANDIDATE_MNT_DIR                          = "${MENDER/KERNEL_ROOT_CANDIDATE_MNT_DIR}"

MENDER/LUKS_DM_MAPPER_DIR                                   = "/dev/mapper"
MENDER/LUKS__DATA__PART___DM_NAME                           = "DataPart${MENDER_DATA_PART_NUMBER}"
MENDER/LUKS__SWAP__PART___DM_NAME                           = "SwapPart"
MENDER/LUKS_ROOTFS_PART_A_DM_NAME                           = "RootfsPart${MENDER_ROOTFS_PART_A_NUMBER}"
MENDER/LUKS_ROOTFS_PART_B_DM_NAME                           = "RootfsPart${MENDER_ROOTFS_PART_B_NUMBER}"

MENDER/LUKS_SYSTEMD_INITRD_CREDENTIALS_DIR                  = "/run/credentials/@initrd"
MENDER/LUKS_SYSTEMD_CRYPTSETUP_PASSPHRASE_CREDENTIAL        = "cryptsetup.passphrase"
MENDER/LUKS_SYSTEMD_CRYPTENROLL_PASSPHRASE_CREDENTIAL       = "cryptenroll.passphrase"

MENDER/LUKS_PARTUUID_IS_USED = "${@bb.utils.contains('MENDER_FEATURES_ENABLE', 'mender-partuuid', 'true', 'false', d)}"
