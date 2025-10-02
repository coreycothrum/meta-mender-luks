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
  local IMAGE_PATH="${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.${suffix}"

  bbplain "\n${IMAGE_PATH} IS NOT yet encrypted.\n\nThis is fine for mender artifact(s), but not for disk provisioning.\n"

  if [ "${MENDER/LUKS_PRINT_REENCRYPT_USAGE}" = "1" ]; then
    bbplain "To encrypt:"
    bbplain "    bitbake mender-luks-cryptsetup-utils-native -caddto_recipe_sysroot \\"
    bbplain "    && PASSWORD=\"${MENDER/LUKS_PASSWORD}\" NEWPASSWORD=\"${MENDER/LUKS_PASSWORD_REENCRYPT}\" oe-run-native mender-luks-cryptsetup-utils-native \\"
    bbplain "       mender-luks-cryptsetup-reencrypt-image-file.sh ${IMAGE_PATH}"
    bbplain "\n"
  fi
  bbplain "For more information, visit: https://github.com/coreycothrum/meta-mender-luks/tree/master#image-encryption\n"
}
