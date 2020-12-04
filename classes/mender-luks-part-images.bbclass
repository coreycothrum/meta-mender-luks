python () {
  fstypes = d.getVar('IMAGE_FSTYPES') + " " + d.getVar("ARTIFACTIMG_FSTYPE")
  handled = set()

  for image_type in fstypes.split():
    # add encrypt deps, task(s)
    if not int(d.getVar('MENDER/LUKS_BYPASS_ENCRYPTION', "0")):
      task = "do_image_%s" % image_type
  
      if not bb.data.inherits_class("image", d):
        continue
  
      if task in handled:
        continue

      d.appendVarFlag(task, "depends", d.expand(' ${MENDER/LUKS_PART_IMAGE_DEPENDS}'))
      handled.add(task)
}

################################################################################
IMAGE_CMD_bootimg_append() {
  local boot_real_sz="${MENDER_BOOT_PART_SIZE_MB}"
  local boot_need_sz="${@mender_kernel_calc_dir_size_mb("${WORKDIR}/bootfs.${BB_CURRENTTASK}")}"

  if [ "$boot_real_sz" -le "0" ]; then
    bbfatal "mender-luks requires MENDER_BOOT_PART_SIZE_MB > 0"
  fi

  if [ "$boot_need_sz" -ge "$boot_real_sz" ]; then
    bbfatal "$boot_real_sz MB is too small, attempted to write $boot_need_sz MB to bootimg"
  fi
}

################################################################################
IMAGE_CMD_biosimg_append() {
  do_mender_luks_encrypt_image "biosimg"
}
IMAGE_CMD_gptimg_append() {
  do_mender_luks_encrypt_image "gptimg"
}
IMAGE_CMD_sdimg_append() {
  do_mender_luks_encrypt_image "sdimg"
}
IMAGE_CMD_uefiimg_append() {
  do_mender_luks_encrypt_image "uefiimg"
}

################################################################################
do_mender_luks_encrypt_image() {
  if [ "${MENDER/LUKS_BYPASS_ENCRYPTION}" -eq "1" ]; then
    bbwarn "!!! MENDER/LUKS_BYPASS_ENCRYPTION is set, skipping encryption"                      \
           "!!! this is not suitable for device provisioning, only generating mender artifacts" \
           "!!! again.... devices provisioned with this build will fail to boot"
    return 0
  fi

  local suffix="$1"
  local sudo_cmd="${MENDER/LUKS_SUDO_CMD}"

  set +e
  {
    $sudo_cmd dmsetup remove_all --force
    $sudo_cmd losetup
    $sudo_cmd losetup -D
    
    local DEV_BASE=$($sudo_cmd losetup -f --show -P "${IMGDEPLOYDIR}/${IMAGE_NAME}.${suffix}")

    do_mender_luks_encrypt_part "${DEV_BASE}p${MENDER_DATA_PART_NUMBER}"           \
                                "${MENDER/LUKS__DATA__PART___DM_NAME}"             \
                                "${IMAGE_ROOTFS}${MENDER/LUKS__DATA__PART___HEADER}"

    do_mender_luks_encrypt_part "${DEV_BASE}p${MENDER_ROOTFS_PART_A_NUMBER}"       \
                                "${MENDER/LUKS_ROOTFS_PART_A_DM_NAME}"             \
                                "${IMAGE_ROOTFS}${MENDER/LUKS_ROOTFS_PART_A_HEADER}"

    do_mender_luks_encrypt_part "${DEV_BASE}p${MENDER_ROOTFS_PART_B_NUMBER}"       \
                                "${MENDER/LUKS_ROOTFS_PART_B_DM_NAME}"             \
                                "${IMAGE_ROOTFS}${MENDER/LUKS_ROOTFS_PART_B_HEADER}"

    ##FIXME - extra parts to encrypt?

    $sudo_cmd dmsetup remove_all --force
    $sudo_cmd losetup -D
    $sudo_cmd losetup
  }
  set -e
}

do_mender_luks_encrypt_part() {
  local DEV="$1"
  local DM_NAME="$2"
  local HEADER="$3"
  local sudo_cmd="${MENDER/LUKS_SUDO_CMD}"

  if   [ ! -f "$HEADER" ]; then
    bbfatal "do_mender_luks_encrypt_part()::header($HEADER) does not exist; cannot encrypt"
  elif [ ! -b "$DEV" ]; then
    bbfatal "do_mender_luks_encrypt_part()::device($DEV) does not exist; cannot encrypt"
  fi

  local LUKS_KEYFILE="${WORKDIR}/key.$(openssl rand -hex 32).luks"
  local LUKS_MASTER_KEYFILE="${WORKDIR}/master.key.$(openssl rand -hex 32).luks"

  echo -n "${MENDER/LUKS_PASSWORD}" > "${LUKS_KEYFILE}"

  cryptsetup  ${MENDER/LUKS_CRYPTSETUP_OPTS_BASE}   \
      --dump-master-key                             \
      --master-key-file    "${LUKS_MASTER_KEYFILE}" \
      --key-file           "${LUKS_KEYFILE}"        \
      --header             "${HEADER}"              \
      luksDump "/dev/zero"

   $sudo_cmd                                        \
   cryptsetup ${MENDER/LUKS_CRYPTSETUP_OPTS_SPECS}  \
      --master-key-file    "${LUKS_MASTER_KEYFILE}" \
      --key-file           "${LUKS_KEYFILE}"        \
      --header             "${HEADER}"              \
      reencrypt --encrypt  "${DEV}" "${DM_NAME}"

  $sudo_cmd cryptsetup luksClose ${DM_NAME}

  shred -fu "${LUKS_KEYFILE}"
  shred -fu "${LUKS_MASTER_KEYFILE}"
}
