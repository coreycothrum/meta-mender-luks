inherit mender-luks-helpers

do_install_append() {
  mender_luks_replace_encrypted_parts ${D}${MENDER_DATA_PART_MOUNT_LOCATION}/mender/mender.conf
}
