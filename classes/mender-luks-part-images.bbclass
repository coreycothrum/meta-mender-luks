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
IMAGE_CMD:bootimg:append() {
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

  bbwarn "\n!!! The created image IS NOT encrypted. That is left for you to (optionally) do post build."                \
         "\n!!! That means this build/image is not yet suitable for device provisioning."                               \
         "\n!!! The mender artifacts however are perfectly usable as-is, so no need to encrypt if that's all you need." \
         "\n!!! To generate an encrypted image suitable for provisioning, run:"                                         \
         "\n"                                                                                                           \
         "\n      bitbake       mender-luks-encrypt-image-native -caddto_recipe_sysroot       && \ "                    \
         "\n      oe-run-native mender-luks-encrypt-image-native mender-luks-encrypt-image.sh    \ "                    \
         "\n        ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.${suffix}"                                                        \
         "\n"                                                                                                           \
         "\n!!! Note that this will likely take a long time to complete. Aborting this script before completion may"    \
         "\n!!! require manual cleanup. See docs for more info."                                                        \
         "\n"
}
