IMAGE_CMD:bootimg:append() {
  local boot_image="${WORKDIR}/bootfs.${MENDER_BOOT_PART_FSTYPE_TO_GEN}"
  local boot_real_sz="${MENDER_BOOT_PART_SIZE_MB}"
  local boot_need_sz="${@mender_kernel_calc_dir_size_mb("$boot_image")}"

  if [ "$boot_real_sz" -le "0" ]; then
    bbfatal "mender-luks requires MENDER_BOOT_PART_SIZE_MB > 0"
  fi

  if [ "$boot_need_sz" -ge "$boot_real_sz" ]; then
    bbfatal "$boot_real_sz MB is too small, attempted to write $boot_need_sz MB to bootimg"
  fi
}

IMAGE_CMD:biosimg:append() {
  do_mender_luks_encrypt_image "biosimg"
}
IMAGE_CMD:gptimg:append() {
  do_mender_luks_encrypt_image "gptimg"
}
IMAGE_CMD:sdimg:append() {
  do_mender_luks_encrypt_image "sdimg"
}
IMAGE_CMD:uefiimg:append() {
  do_mender_luks_encrypt_image "uefiimg"
}

################################################################################
do_mender_luks_encrypt_image() {
  local suffix="$1"
  bbplain "\n${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.${suffix} IS NOT yet encrypted. See meta-mender-luks docs for device provisioning information.\n"
}
