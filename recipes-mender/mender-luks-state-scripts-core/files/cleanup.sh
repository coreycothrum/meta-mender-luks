#!/bin/sh

function log {
  echo "$@" >&2
}

function cleanup {
  sync

  mount | grep -q $ROOT_MNT_DIR/data && umount -l $ROOT_MNT_DIR/data
  mount | grep -q $ROOT_MNT_DIR/dev  && umount -l $ROOT_MNT_DIR/dev
  mount | grep -q $ROOT_MNT_DIR/tmp  && umount -l $ROOT_MNT_DIR/tmp
  mount | grep -q $ROOT_MNT_DIR      && umount -l $ROOT_MNT_DIR
  rm -fr          $ROOT_MNT_DIR

  sync
}
trap cleanup EXIT

################################################################################
ROOT_MNT_DIR="@@MENDER/KERNEL_ROOT_CANDIDATE_MNT_DIR@@"

exit
