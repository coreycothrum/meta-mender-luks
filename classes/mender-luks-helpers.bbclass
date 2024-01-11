mender_luks_replace_encrypted_parts() {
  if [ ! -f "$1" ]; then
    bbfatal "mender_luks_replace_encrypted_parts()::file($1) is not valid or does not exist"
  fi

  if ${@bb.utils.contains('MENDER_FEATURES', 'mender-partuuid', 'true', 'false', d)}; then
    local mender_data_part="PARTUUID=${@os.path.basename(d.getVar('MENDER_DATA_PART'))}"
  else
    local mender_data_part=${MENDER_DATA_PART}
  fi

  #stock mender-luks encrypted partitions
  sed -i -e 's|${MENDER_ROOTFS_PART_A}|${MENDER/LUKS_DM_MAPPER_DIR}/${MENDER/LUKS_ROOTFS_PART_A_DM_NAME}|g' \
         -e 's|${MENDER_ROOTFS_PART_B}|${MENDER/LUKS_DM_MAPPER_DIR}/${MENDER/LUKS_ROOTFS_PART_B_DM_NAME}|g' \
         -e "s|${mender_data_part}|${MENDER/LUKS_DM_MAPPER_DIR}/${MENDER/LUKS__DATA__PART___DM_NAME}|g"     \
         ${1}

  #FIXME - MENDER_EXTRA_PARTS encrypted partitions
  #FIXME - skip kernel partitions, loop over others
}
