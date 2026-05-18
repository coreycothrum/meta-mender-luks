#!/bin/sh
set -e

function log {
  echo "$@" >&2
}

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
