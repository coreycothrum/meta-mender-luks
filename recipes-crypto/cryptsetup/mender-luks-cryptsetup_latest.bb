SUMMARY          = "cryptsetup/crypttab/LUKS configuration and utilities"
DESCRIPTION      = "cryptsetup/crypttab/LUKS configuration and utilities"
LICENSE          = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"
BBCLASSEXTEND    = "native nativesdk"

SRC_URI += " \
  file://crypttab \
  file://mender-luks-cryptsetup-functions.sh \
  file://mender-luks-cryptsetup-reencrypt-image-file.sh \
"
S = "${UNPACKDIR}"

FILES:${PN} = " \
  ${sysconfdir}/crypttab \
  ${MENDER/LUKS_DATA_DIR}/ \
  ${MENDER/LUKS_HEADER_DIR}/ \
  ${sbindir}/mender-luks-cryptsetup-functions.sh \
"

FILES:${PN}:class-native = " \
  ${sbindir}/mender-luks-cryptsetup-reencrypt-image-file.sh \
"

DEPENDS += " \
  coreutils-native \
  cryptsetup-native \
"

RDEPENDS:${PN} = " \
  bash \
  coreutils \
  cryptsetup \
  jq \
  time \
  util-linux \
"

RDEPENDS:${PN}:append:class-native = " \
  bmaptool \
"

################################################################################
inherit bitbake-variable-substitution

do_install() {
  install -d -m 0755                                          ${D}${sbindir}
  install    -m 0755 ${S}/mender-luks-cryptsetup-functions.sh ${D}${sbindir}/

  install -d                                                  ${D}${sysconfdir}
  install    -m 0644 ${S}/crypttab                            ${D}${sysconfdir}

  do_luks_partition_setup "${MENDER/LUKS__DATA__PART___DM_NAME}" "${MENDER_DATA_PART}"
  do_luks_partition_setup "${MENDER/LUKS_ROOTFS_PART_A_DM_NAME}" "${MENDER_ROOTFS_PART_A}"
  do_luks_partition_setup "${MENDER/LUKS_ROOTFS_PART_B_DM_NAME}" "${MENDER_ROOTFS_PART_B}"

  # #FIXME - MENDER_EXTRA_PARTS (does this require kerenl partition mods?)

  if [ "${MENDER_SWAP_PART_SIZE_MB}" -ne "0" ]; then
    echo "${MENDER/LUKS__SWAP__PART___DM_NAME} LABEL=swap /dev/urandom swap" >> ${D}${sysconfdir}/crypttab
  fi
}

do_install:append:class-native() {
  install -d -m 755                                                     ${D}${sbindir}
  install    -m 755 ${S}/mender-luks-cryptsetup-reencrypt-image-file.sh ${D}${sbindir}/
}

################################################################################
# do_luks_partition_setup
#
# Creates LUKS metadata for a target mapper/device pair
# appends the corresponding crypttab entry used at boot.
#
# Required arguments:
#   ${1} : device-mapper name for the LUKS mapping
#   ${2} : source block device path to encrypt
#
# Behavior:
#   - Builds relative/absolute detached header paths.
#   - Writes a crypttab line with common, optional TPM2, and extra options.
#   - Initializes a temporary file as a LUKS2 container and stores the header at ${MENDER/LUKS_HEADER_DIR}.
do_luks_partition_setup() {
  local NAME="${1}"
  local DEV="${2}"
  local HEADER_FILENAME="${NAME}.${MENDER/LUKS_HEADER_EXT}"
  local HEADER_REL_PATH="$(basename ${MENDER/LUKS_HEADER_DIR})/${HEADER_FILENAME}"
  local HEADER_ABS_PATH="${MENDER/LUKS_HEADER_DIR}/${HEADER_FILENAME}"
  local OPTIONS="luks,nofail,x-initrd.attach,${@bb.utils.contains("DISTRO_FEATURES", 'tpm2', 'tpm2-device=${MENDER/LUKS_TPM2_DEVICE}', '', d)}"

  echo "${NAME} ${DEV} none ${OPTIONS},${MENDER/LUKS_CRYPTTAB_EXTRA_OPTIONS},header=${HEADER_REL_PATH}:${MENDER_BOOT_PART}" >> ${D}${sysconfdir}/crypttab

  local TMP_FS="${UNPACKDIR}/tmp.luks"
  dd if=/dev/zero of="${TMP_FS}" bs=1M count=512

  install -d -m 0755 $(dirname ${D}${HEADER_ABS_PATH})

  printf '%s' "${MENDER/LUKS_PASSWORD}"       | \
  cryptsetup --batch-mode --type luks2          \
    ${MENDER/LUKS_CRYPTSETUP_REENCRYPT_OPTIONS} \
    --force-password                            \
    --header "${D}${HEADER_ABS_PATH}"           \
    --key-file -                                \
    reencrypt --encrypt --init-only "${TMP_FS}"
}