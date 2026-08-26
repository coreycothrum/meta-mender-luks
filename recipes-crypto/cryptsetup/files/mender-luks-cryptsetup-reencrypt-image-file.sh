#!/usr/bin/env bash
################################################################################
usage() {
  echo "Usage:"
  echo "  PASSWORD=\"<current-luks-password>\" NEWPASSWORD=\"<new-luks-password>\" [REENCRYPT_OPTIONS=\"<cryptsetup reencrypt options>\"] $(basename "$0") <path/to/YOCTO_IMAGE.uefiimg>"
  echo
  echo "Required:"
  echo "  PASSWORD          Current LUKS passphrase"
  echo "  image path        Existing .uefiimg file to process"
  echo
  echo "Optional:"
  echo "  NEWPASSWORD       New LUKS passphrase"
  echo "  REENCRYPT_OPTIONS Extra options passed to 'cryptsetup reencrypt'"
  echo
  echo "Example:"
  echo "  PASSWORD=\"old-pass\" NEWPASSWORD=\"new-pass\" REENCRYPT_OPTIONS=\"--init-only\" $(basename "$0") /path/to/core-image.uefiimg"
}

IMAGE="$1"

[[ ! -v   PASSWORD ]] && usage && exit
[[   -z "${IMAGE}" ]] && usage && exit
[[ ! -f "${IMAGE}" ]] && usage && exit

################################################################################
set -eu
source mender-luks-cryptsetup-functions.sh

WORKDIR="$(mktemp --directory)"
BOOT_MNT="${WORKDIR}/@@MENDER_BOOT_PART_MOUNT_LOCATION@@"

################################################################################
dmsetup_remove() {
  do_sudo find @@MENDER/LUKS_DM_MAPPER_DIR@@ -iname "${1}*" -exec dmsetup remove --force {} \;
}

cleanup() {
  set +e
    for_each_in_crypttab "dmsetup_remove \${NAME}"

    do_sudo umount  "${BOOT_MNT}" > /dev/null 2>&1
    do_sudo losetup               > /dev/null 2>&1
    do_sudo losetup -D            > /dev/null 2>&1
    do_sudo sync
  set -eu

  shred -fu "${WORKDIR}"/* 2>/dev/null
  rm    -fr "${WORKDIR}"
}
cleanup && trap 'cleanup' EXIT

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

  luks_reencrypt
  luks_change_key

  return 0
}
for_each_in_crypttab _do_task

cleanup
echo "creating bmap: ${IMAGE}" && bmaptool create -o "${IMAGE}.bmap" "${IMAGE}"
echo "$(basename ${IMAGE}) can now provision new systems:"
echo "    bmaptool copy ${IMAGE} <DEST>"
