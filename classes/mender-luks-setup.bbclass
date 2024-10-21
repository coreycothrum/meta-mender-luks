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
  if   bb.utils.contains('MENDER_FEATURES_ENABLE', 'mender-ubi'        , True, False, d):
    bb.fatal("mender-luks does not currently support mender-ubi")

  elif bb.utils.contains('MENDER_FEATURES_ENABLE', 'mender-image-ubi'  , True, False, d):
    bb.fatal("mender-luks does not currently support mender-image-ubi")

  elif bb.utils.contains('MENDER_FEATURES_ENABLE', 'mender-uboot'      , True, False, d):
    bb.fatal("mender-luks does not currently support mender-uboot")

  ##############################################################################
  if not bb.utils.contains('DISTRO_FEATURES', 'systemd', True, False, d):
    bb.fatal("mender-luks requires systemd")

  ##############################################################################
  if     bb.utils.contains('DISTRO_FEATURES', 'tpm'    , True, False, d):
    bb.fatal("mender-luks does not currently support TPM (1.0)")

  ##############################################################################
  reencrypt_on_init       = (d.getVar("MENDER/LUKS_REENCRYPT_ON_INIT")                   == "1")
  use_passwd              = (d.getVar("MENDER/LUKS_CRYPTENROLL_PASSWORD")                == "1")
  use_passwd_wipe_on_init = (d.getVar("MENDER/LUKS_CRYPTENROLL_PASSWORD_WIPE_ON_INIT")   == "1")
  use_passwd_forbid_empty = (d.getVar("MENDER/LUKS_CRYPTENROLL_PASSWORD_FORBID_EMPTY")   == "1")
  use_passwd_strong       = (d.getVar("MENDER/LUKS_CRYPTENROLL_PASSWORD_ENFORCE_STRONG") == "1")
  use_tpm2                = (d.getVar("MENDER/LUKS_CRYPTENROLL_TPM2")                    == "1")
  unattended_boot         = use_tpm2

  if use_passwd_strong and not use_passwd_forbid_empty:
    bb.warn("MENDER/LUKS_CRYPTENROLL_PASSWORD_ENFORCE_STRONG is set, but MENDER/LUKS_CRYPTENROLL_PASSWORD_FORBID_EMPTY is not... an empty password will be allowed...");

  if not unattended_boot:
    if not use_passwd              : bb.fatal("LUKS partition(s) will init with only a random recovery key. May not be able to boot after init.")
    if     use_passwd_wipe_on_init : bb.warn ("LUKS partition(s) will init with only a random recovery key. May not be able to boot after init.")
}
addhandler do_mender_luks_checks
do_mender_luks_checks[eventmask] = "bb.event.ParseCompleted"
