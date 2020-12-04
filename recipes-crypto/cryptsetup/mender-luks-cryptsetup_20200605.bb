SUMMARY          = "Install cryptsetup files for LUKS encryption"
DESCRIPTION      = "Install cryptsetup files for LUKS encryption"
LICENSE          = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI         += "file://crypttab"
FILES_${PN}      = "                            \
                     ${sysconfdir}/crypttab     \
                     ${MENDER/LUKS_KEY_FILE}    \
                     ${MENDER/LUKS_HEADER_DIR}/ \
                   "

DEPENDS         += "                   \
                     coreutils-native  \
                     cryptsetup-native \
                   "

do_install() {
    ############################################################################
    # LUKS keyfile in persistent storage (encrypted partition)
    ############################################################################
    install -d -m 400                              ${D}$(dirname ${MENDER/LUKS_KEY_FILE})
    echo    -n "${MENDER/LUKS_PASSWORD}" > ${WORKDIR}/$(basename ${MENDER/LUKS_KEY_FILE})
    install    -m 400                      ${WORKDIR}/$(basename ${MENDER/LUKS_KEY_FILE}) ${D}${MENDER/LUKS_KEY_FILE}

    ############################################################################
    # create /etc/crypttab
    ############################################################################
    install -d                          ${D}${sysconfdir}
    install -m 0644 ${WORKDIR}/crypttab ${D}${sysconfdir}

    echo "${MENDER/LUKS__DATA__PART___DM_NAME} ${MENDER_DATA_PART}     none luks,nofail,header=${MENDER/LUKS__DATA__PART___HEADER}"  > ${D}${sysconfdir}/crypttab
    echo "${MENDER/LUKS_ROOTFS_PART_A_DM_NAME} ${MENDER_ROOTFS_PART_A} none luks,nofail,header=${MENDER/LUKS_ROOTFS_PART_A_HEADER}" >> ${D}${sysconfdir}/crypttab
    echo "${MENDER/LUKS_ROOTFS_PART_B_DM_NAME} ${MENDER_ROOTFS_PART_B} none luks,nofail,header=${MENDER/LUKS_ROOTFS_PART_B_HEADER}" >> ${D}${sysconfdir}/crypttab

    #FIXME - extra parts to encrypt?

    if [ "${MENDER_SWAP_PART_SIZE_MB}" -ne "0" ]; then
      #FIXME - swap needs to be tested?
      echo "${MENDER/LUKS__SWAP__PART___DM_NAME}    LABEL=swap    /dev/urandom    swap"  >> ${D}${sysconfdir}/crypttab
    fi

    ############################################################################
    # create LUKS headers
    ############################################################################
    install -d -m 755                 ${D}$(dirname ${MENDER/LUKS__DATA__PART___HEADER})
    mender_luks_create_header ${WORKDIR}/$(basename ${MENDER/LUKS__DATA__PART___HEADER})
    install    -m 0664        ${WORKDIR}/$(basename ${MENDER/LUKS__DATA__PART___HEADER}) ${D}${MENDER/LUKS_HEADER_DIR}/

    install -d -m 755                 ${D}$(dirname ${MENDER/LUKS_ROOTFS_PART_A_HEADER})
    mender_luks_create_header ${WORKDIR}/$(basename ${MENDER/LUKS_ROOTFS_PART_A_HEADER})
    install    -m 0664        ${WORKDIR}/$(basename ${MENDER/LUKS_ROOTFS_PART_A_HEADER}) ${D}${MENDER/LUKS_HEADER_DIR}/

    install -d -m 755                 ${D}$(dirname ${MENDER/LUKS_ROOTFS_PART_B_HEADER})
    mender_luks_create_header ${WORKDIR}/$(basename ${MENDER/LUKS_ROOTFS_PART_B_HEADER})
    install    -m 0664        ${WORKDIR}/$(basename ${MENDER/LUKS_ROOTFS_PART_B_HEADER}) ${D}${MENDER/LUKS_HEADER_DIR}/

    #FIXME - extra parts to encrypt?
}

################################################################################
mender_luks_create_header() {
  if [ -z "$1" ]; then
    bbfatal "mender_luks_create_header(): must pass a valid filename"
  fi

  local HEADER="$1"
  local LUKS_TMP_FS="tmp.luks"
  local LUKS_KEYFILE="passwd.luks"

  rm -fr "${HEADER}"

  dd if=/dev/zero of=${LUKS_TMP_FS} bs=1M count=512

  echo -n "${MENDER/LUKS_PASSWORD}" > "${LUKS_KEYFILE}"

  cryptsetup ${MENDER/LUKS_CRYPTSETUP_OPTS_SPECS} \
      --key-file "${LUKS_KEYFILE}"                \
      --header   "${HEADER}"                      \
      luksFormat "${LUKS_TMP_FS}"

  shred -fu "${LUKS_TMP_FS}"
  shred -fu "${LUKS_KEYFILE}"
}
