inherit mender-luks-helpers

IMAGE_CLASSES += "        \
  mender-luks-part-images \
"

################################################################################
mender_update_fstab_file:append() {
  mender_luks_replace_encrypted_parts ${IMAGE_ROOTFS}${sysconfdir}/fstab
}

################################################################################
python do_mender_luks_checks() {
  if   bb.utils.contains('MENDER_FEATURES_ENABLE', 'mender-ubi', True, False, d):
    bb.fatal("mender-luks does not currently support mender-ubi")

  elif bb.utils.contains('MENDER_FEATURES_ENABLE', 'mender-image-ubi', True, False, d):
    bb.fatal("mender-luks does not currently support mender-image-ubi")

  elif bb.utils.contains('MENDER_FEATURES_ENABLE', 'mender-uboot', True, False, d):
    bb.fatal("mender-luks does not currently support mender-uboot")

  ##############################################################################
  if not bb.utils.contains('DISTRO_FEATURES', 'systemd', True, False, d):
    bb.fatal("mender-luks requires systemd")

  ##############################################################################
  if bb.utils.contains('DISTRO_FEATURES', 'tpm', True, False, d):
    bb.fatal("mender-luks does not support TPM (1.0)")
}
addhandler do_mender_luks_checks
do_mender_luks_checks[eventmask] = "bb.event.ParseCompleted"
