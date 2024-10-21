SUMMARY          = "LUKS cryptsetup/crypttab config"
DESCRIPTION      = "LUKS cryptsetup/crypttab config"
LICENSE          = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"
BBCLASSEXTEND    = "native nativesdk"

SRC_URI += "      \
  file://crypttab \
"

FILES:${PN} = "              \
  ${sysconfdir}/crypttab     \
  ${MENDER/LUKS_DATA_DIR}/   \
  ${MENDER/LUKS_HEADER_DIR}/ \
"

DEPENDS += "       \
  coreutils-native \
"

RDEPENDS:${PN} = " \
  cryptsetup       \
"

do_install() {
  install -d -m 0755                     ${D}${MENDER/LUKS_DATA_DIR}/
  install -d -m 0755                     ${D}${MENDER/LUKS_HEADER_DIR}/
  install -d                             ${D}${sysconfdir}
  install    -m 0644 ${WORKDIR}/crypttab ${D}${sysconfdir}

  echo "${MENDER/LUKS__DATA__PART___DM_NAME} ${MENDER_DATA_PART}     none ${MENDER/LUKS_CRYPTTAB_OPTS},header=${MENDER/LUKS__DATA__PART___HEADER}"  > ${D}${sysconfdir}/crypttab
  echo "${MENDER/LUKS_ROOTFS_PART_A_DM_NAME} ${MENDER_ROOTFS_PART_A} none ${MENDER/LUKS_CRYPTTAB_OPTS},header=${MENDER/LUKS_ROOTFS_PART_A_HEADER}" >> ${D}${sysconfdir}/crypttab
  echo "${MENDER/LUKS_ROOTFS_PART_B_DM_NAME} ${MENDER_ROOTFS_PART_B} none ${MENDER/LUKS_CRYPTTAB_OPTS},header=${MENDER/LUKS_ROOTFS_PART_B_HEADER}" >> ${D}${sysconfdir}/crypttab

  # #FIXME - MENDER_EXTRA_PARTS

  if [ "${MENDER_SWAP_PART_SIZE_MB}" -ne "0" ]; then
    echo "${MENDER/LUKS__SWAP__PART___DM_NAME} LABEL=swap /dev/urandom swap" >> ${D}${sysconfdir}/crypttab
  fi
}
