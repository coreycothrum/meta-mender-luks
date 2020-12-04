#!/bin/sh
set -e

function log {
  echo "$@" >&2
}
log "$(cat /etc/mender/artifact_info): $(basename "$0") was called!"

function cleanup {
  sync

  if mount | grep -q $ROOT_MNT_DIR; then
    umount           $ROOT_MNT_DIR
  fi
  rm -fr             $ROOT_MNT_DIR

  sync
}
trap cleanup EXIT

################################################################################
ROOT_MNT_DIR="@@MENDER/KERNEL_ROOT_CANDIDATE_MNT_DIR@@"

exit
