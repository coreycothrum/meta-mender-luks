#!/usr/bin/env bash
################################################################################
usage() {
  echo "usage:"
  echo "    PASSWORD=\"LUKS_PASSWORD\" $(basename $0) /path/to/YOCTO_IMAGE.uefiimg"
}

IMAGE="$1"

[[ ! -v    PASSWORD ]] && usage && exit
[[ ! -v NEWPASSWORD ]] && NEWPASSWORD="${PASSWORD}"
[[   -z "${IMAGE}"  ]] && usage && exit
[[ ! -f "${IMAGE}"  ]] && usage && exit

################################################################################
set -eu
source mender-luks-cryptsetup-functions.sh

BOOT_MNT="${WORKDIR}/@@MENDER_BOOT_PART_MOUNT_LOCATION@@"

################################################################################
dmsetup_remove() {
  do_sudo find @@MENDER/LUKS_DM_MAPPER_DIR@@ -iname "${1}*" -exec dmsetup remove --force {} \;
}

cleanup() {
  set +e
    for_each_in_crypttab "luks_close     \${NAME}"
    for_each_in_crypttab "dmsetup_remove \${NAME}"

    do_sudo losetup               > /dev/null 2>&1
    do_sudo losetup -D            > /dev/null 2>&1
    do_sudo umount  "${BOOT_MNT}" > /dev/null 2>&1
    do_sudo sync
  set -eu
}
cleanup && trap 'cleanup; mender_luks_cryptsetup_cleanup' EXIT

################################################################################
################################################################################
################################################################################
BASE_DEV=$(do_sudo losetup --find --show --partscan "${IMAGE}")
BOOT_DEV="${BASE_DEV}p@@MENDER_BOOT_PART_NUMBER@@"

[[ ! -d "${BOOT_MNT}" ]] && mkdir -p "${BOOT_MNT}"
[[   -z "${BASE_DEV}" ]] && fatal "process_image: losetup failed to return valid loopback device"
[[ ! -b "${BOOT_DEV}" ]] && fatal "process_image::device(${BOOT_DEV}) does not exist"

do_sudo mount "${BOOT_DEV}" "${BOOT_MNT}"

_do_task() {
  local NAME="${NAME}"
  local DEV="$(echo "${DEV}" | sed "s|@@MENDER_STORAGE_DEVICE_BASE@@|${BASE_DEV}p|g")"
  local HEADER="${WORKDIR}/${HEADER}"

                            luks_reencrypt  "${NAME}" "${DEV}" "${HEADER}"
                            luks_change_key "${NAME}" "${DEV}" "${HEADER}"
  PASSWORD="${NEWPASSWORD}" luks_open       "${NAME}" "${DEV}" "${HEADER}"

     [[ ! -v LEGACYPASSWORD ]] && local LEGACYPASSWORD="${NEWPASSWORD}"
  if [[   -v LEGACYPASSWORD ]]; then
    if [[ "${NAME}" == "@@MENDER/LUKS__DATA__PART___DM_NAME@@" ]]; then
      local DATA_DEV="@@MENDER/LUKS_DM_MAPPER_DIR@@/@@MENDER/LUKS__DATA__PART___DM_NAME@@"
      local DATA_MNT="${WORKDIR}/@@MENDER_DATA_PART_MOUNT_LOCATION@@"
      local KEY_FILE="$(mktemp --tmpdir=${WORKDIR})"

      mkdir   -p                              "${DATA_MNT}"
      do_sudo mount     "${DATA_DEV}"         "${DATA_MNT}"
      echo    -n        "${LEGACYPASSWORD}" > "${KEY_FILE}"
      do_sudo install -m 400 -D               "${KEY_FILE}" "${WORKDIR}/@@MENDER/LUKS_LEGACY_KEY_FILE@@"
      do_sudo umount                          "${DATA_MNT}"
    fi
  fi
  luks_close      "${NAME}"

  return 0
}
for_each_in_crypttab _do_task

cleanup && echo "creating bmap" && bmaptool create -o "${IMAGE}.bmap" "${IMAGE}"
echo "$(basename ${IMAGE}) can now provision new systems:"
echo "    bmaptool copy ${IMAGE} <DEST>"

################################################################################
