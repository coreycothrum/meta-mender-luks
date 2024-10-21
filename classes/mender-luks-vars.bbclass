################################################################################
# meta-mender-luks variables
################################################################################
MENDER/LUKS_CRYPTENROLL_PASSWORD                ??= "0"
MENDER/LUKS_CRYPTENROLL_PASSWORD_ENFORCE_STRONG ??= "${@bb.utils.contains('MENDER/LUKS_CRYPTENROLL_PASSWORD', '1'   , '1', '0', d)}"
MENDER/LUKS_CRYPTENROLL_PASSWORD_FORBID_EMPTY   ??= "${@bb.utils.contains('MENDER/LUKS_CRYPTENROLL_PASSWORD', '1'   , '1', '0', d)}"
MENDER/LUKS_CRYPTENROLL_PASSWORD_WIPE_ON_INIT   ??= "${@bb.utils.contains('MENDER/LUKS_CRYPTENROLL_PASSWORD', '1'   , '1', '0', d)}"
MENDER/LUKS_CRYPTENROLL_TPM2                    ??= "${@bb.utils.contains('DISTRO_FEATURES'                 , 'tpm2', '1', '0', d)}"
MENDER/LUKS_CRYPTENROLL_TPM2_SEALED_PCRS        ??= "7+11"

MENDER/LUKS_REENCRYPT_ON_INIT                   ??= "1"

MENDER/LUKS_TPM2_DEVICE                         ??= "auto"
MENDER/LUKS_CRYPTTAB_OPTS                       ??= "luks,nofail,tries=0,try-empty-password=true,${@bb.utils.contains('DISTRO_FEATURES', 'tpm2', 'tpm2-device=${MENDER/LUKS_TPM2_DEVICE}', '', d)}"

################################################################################
# #TODO: DEPRECATE #FIXME
MENDER/LUKS_PASSWORD_AGENT_CMD                  ??= "${@bb.utils.contains('DISTRO_FEATURES', 'tpm2', 'mender-luks-tpm2-util.sh --read', ':', d)}"
MENDER/LUKS_LEGACY_COMPAT                       ??= "1"

################################################################################
MENDER/LUKS_DATA_DIR                              = "${MENDER_DATA_PART_MOUNT_LOCATION}/luks"
MENDER/LUKS_HEADER_DIR                            = "${MENDER_BOOT_PART_MOUNT_LOCATION}/LUKS"
MENDER/LUKS_HEADER_EXT                            = "luks"
MENDER/LUKS_KERNEL_DIR                            = "${MENDER_BOOT_PART_MOUNT_LOCATION}/EFI/Linux"
MENDER/LUKS_LEGACY_KEY_FILE                       = "${MENDER/LUKS_DATA_DIR}/.key.luks"
MENDER/LUKS_RECOVERY_EXT                          = "recovery"
MENDER/LUKS_SYSTEMD_INITRD_CREDENTIALS_DIR        = "/run/credentials/@initrd"

MENDER/LUKS_ROOTFS_PART_A_HEADER                  = "${MENDER/LUKS_HEADER_DIR}/${MENDER/LUKS_ROOTFS_PART_A_HEADER_NAME}"
MENDER/LUKS_ROOTFS_PART_B_HEADER                  = "${MENDER/LUKS_HEADER_DIR}/${MENDER/LUKS_ROOTFS_PART_B_HEADER_NAME}"
MENDER/LUKS__DATA__PART___HEADER                  = "${MENDER/LUKS_HEADER_DIR}/${MENDER/LUKS__DATA__PART___HEADER_NAME}"

MENDER/LUKS_ROOTFS_PART_A_HEADER_NAME             = "${MENDER/LUKS_ROOTFS_PART_A_DM_NAME}.${MENDER/LUKS_HEADER_EXT}"
MENDER/LUKS_ROOTFS_PART_B_HEADER_NAME             = "${MENDER/LUKS_ROOTFS_PART_B_DM_NAME}.${MENDER/LUKS_HEADER_EXT}"
MENDER/LUKS__DATA__PART___HEADER_NAME             = "${MENDER/LUKS__DATA__PART___DM_NAME}.${MENDER/LUKS_HEADER_EXT}"

MENDER/LUKS_DM_MAPPER_DIR                         = "/dev/mapper"
MENDER/LUKS__DATA__PART___DM_NAME                 = "DataPart${MENDER_DATA_PART_NUMBER}"
MENDER/LUKS__SWAP__PART___DM_NAME                 = "SwapPart"
MENDER/LUKS_ROOTFS_PART_A_DM_NAME                 = "RootfsPart${MENDER_ROOTFS_PART_A_NUMBER}"
MENDER/LUKS_ROOTFS_PART_B_DM_NAME                 = "RootfsPart${MENDER_ROOTFS_PART_B_NUMBER}"

################################################################################
MENDER/LUKS_DENY_IMAGE_TYPES                      = "             \
                                                      biosimg.bz2 \
                                                      gptimg.bz2  \
                                                      sdimg.bz2   \
                                                      uefiimg.bz2 \
                                                      hddimg      \
                                                      wic         \
                                                    "
MENDER/LUKS_PARTUUID_IS_USED                      = "${@bb.utils.contains('MENDER_FEATURES_ENABLE', 'mender-partuuid', '1', '0', d)}"
