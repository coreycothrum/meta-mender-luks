inherit mender-luks-helpers

IMAGE_CLASSES += "        \
  mender-luks-part-images \
"

################################################################################
mender_update_fstab_file_append() {
  mender_luks_replace_encrypted_parts ${IMAGE_ROOTFS}${sysconfdir}/fstab
}

################################################################################
python do_mender_luks_checks() {
  if   bb.utils.contains('MENDER_FEATURES_ENABLE', 'mender-ubi'        , True, False, d):
    bb.fatal("mender-luks does not currently support mender-ubi")

  elif bb.utils.contains('MENDER_FEATURES_ENABLE', 'mender-image-ubi'  , True, False, d):
    bb.fatal("mender-luks does not currently support mender-image-ubi")

  elif bb.utils.contains('MENDER_FEATURES_ENABLE', 'mender-uboot'      , True, False, d):
    bb.fatal("mender-luks does not currently support mender-uboot")

  elif bb.utils.contains('MENDER_FEATURES_ENABLE', 'mender-partuuid'   , True, False, d):
    bb.fatal("mender-luks does not currently support mender-partuuid")

  ##############################################################################
  if not bb.utils.contains('DISTRO_FEATURES', 'systemd', True, False, d):
    bb.fatal("mender-luks requires systemd")

  ##############################################################################
  if     bb.utils.contains('DISTRO_FEATURES', 'tpm'    , True, False, d):
    bb.fatal("mender-luks does not currently support TPM (1.0)")

  ##############################################################################
  if       bb.utils.contains('MENDER/LUKS_BYPASS_RANDOM_KEY', '0'   , True, False, d):
    if not bb.utils.contains('DISTRO_FEATURES'              , 'tpm2', True, False, d):
      bb.fatal("MENDER/LUKS_BYPASS_RANDOM_KEY is enabled, but no TPM2 present. This would lock system after first boot with a random, unknown, password.")

  passwd         = str(d.getVar('MENDER/LUKS_PASSWORD'        , '')).lower()
  passwd_default = str(d.getVar('MENDER/LUKS_PASSWORD_DEFAULT', '')).lower()

  if (passwd in passwd_default) or (passwd_default in passwd):
    bb.fatal("MENDER/LUKS_PASSWORD_DEFAULT (%s) is too similar to default (%s)" % (passwd, passwd_default))

}
addhandler do_mender_luks_checks
do_mender_luks_checks[eventmask] = "bb.event.ParseCompleted"
