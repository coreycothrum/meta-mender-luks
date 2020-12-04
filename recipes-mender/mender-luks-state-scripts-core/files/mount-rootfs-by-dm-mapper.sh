#!/bin/sh
set -e

function log {
  echo "$@" >&2
}
log "$(cat /etc/mender/artifact_info): $(basename "$0") was called!"

function fatal {
  log $@
  exit 1
}

################################################################################
BOOT_PART="$(fw_printenv mender_boot_part | sed 's/[^=]*=//')"
ROOT_PART=""

ROOT_MNT_DIR="@@MENDER/KERNEL_ROOT_CANDIDATE_MNT_DIR@@"

#BOOT_PART :   active partition
#ROOT_PART : inactive partition
if   [ "$BOOT_PART" -eq "@@MENDER_ROOTFS_PART_A_NUMBER@@" ]; then
  ROOT_PART="@@MENDER/LUKS_DM_MAPPER_DIR@@/@@MENDER/LUKS_ROOTFS_PART_B_DM_NAME@@"

elif [ "$BOOT_PART" -eq "@@MENDER_ROOTFS_PART_B_NUMBER@@" ]; then
  ROOT_PART="@@MENDER/LUKS_DM_MAPPER_DIR@@/@@MENDER/LUKS_ROOTFS_PART_A_DM_NAME@@"

else
  fatal "$BOOT_PART is not a known/valid rootfs partition"
fi

if ! mount |        grep -q $ROOT_MNT_DIR; then
  mkdir -p                  $ROOT_MNT_DIR
  mount -o ro  $ROOT_PART   $ROOT_MNT_DIR
  log "mounted $ROOT_PART @ $ROOT_MNT_DIR"
fi

exit
