#!/usr/bin/env bash
################################################################################
set -e

WORKDIR="/tmp/mender_luks_encrypt_WORK_TMP"
BOOTDIR="/tmp/mender_luks_encrypt_BOOT_TMP"

################################################################################
function log {
  echo "$@" >&2
}

################################################################################
function usage {
  log "usage: $(basename $0) path_to_deployed_IMAGE_NAME"
}

################################################################################
function fatal {
  log "error encountered; aborting"
  log "encryption did not finish. loopback devices *may* still be open."
  log "check and cleanup manually as needed: sudo losetup && sudo losetup -D"
  log $@
  exit 1
}

################################################################################
function cleanup {
  set +e
  @@MENDER/LUKS_SUDO_CMD@@ dmsetup remove --force @@MENDER/LUKS__DATA__PART___DM_NAME@@ > /dev/null 2>&1
  @@MENDER/LUKS_SUDO_CMD@@ dmsetup remove --force @@MENDER/LUKS_ROOTFS_PART_A_DM_NAME@@ > /dev/null 2>&1
  @@MENDER/LUKS_SUDO_CMD@@ dmsetup remove --force @@MENDER/LUKS_ROOTFS_PART_B_DM_NAME@@ > /dev/null 2>&1
  @@MENDER/LUKS_SUDO_CMD@@ losetup                                                      > /dev/null 2>&1
  @@MENDER/LUKS_SUDO_CMD@@ losetup -D                                                   > /dev/null 2>&1
  @@MENDER/LUKS_SUDO_CMD@@ shred   -fu    "${WORKDIR}/*"                                > /dev/null 2>&1
  @@MENDER/LUKS_SUDO_CMD@@ rm      -fr    "${WORKDIR}"                                  > /dev/null 2>&1
  @@MENDER/LUKS_SUDO_CMD@@ umount         "${BOOTDIR}"                                  > /dev/null 2>&1
  @@MENDER/LUKS_SUDO_CMD@@ rm      -fr    "${BOOTDIR}"                                  > /dev/null 2>&1
  @@MENDER/LUKS_SUDO_CMD@@ sync                                                         > /dev/null 2>&1
  set -e
}
trap cleanup EXIT

################################################################################
function mender_luks_encrypt_part {
  local DEV="$1"
  local DM_NAME="$2"
  local HEADER="$3"

  if   [ ! -f "$HEADER" ]; then
    fatal "mender_luks_encrypt_part::header($HEADER) does not exist; cannot encrypt"
  elif [ ! -b "$DEV" ]; then
    fatal "mender_luks_encrypt_part::device($DEV)    does not exist; cannot encrypt"
  elif [   -z "$DM_NAME" ]; then
    fatal "mender_luks_encrypt_part: missing function parameter DM_NAME"
  fi

  local LUKS_KEYFILE="${WORKDIR}/key.$(openssl rand -hex 32).luks"
  local LUKS_MASTER_KEYFILE="${WORKDIR}/master.key.$(openssl rand -hex 32).luks"
  local LUKS_KEYSLOT="@@MENDER/LUKS_PRIMARY_KEY_SLOT@@"

  echo -n "@@MENDER/LUKS_PASSWORD@@" > "${LUKS_KEYFILE}"

  cryptsetup @@MENDER/LUKS_CRYPTSETUP_OPTS_BASE@@   \
      --dump-master-key                             \
      --master-key-file    "${LUKS_MASTER_KEYFILE}" \
      --key-slot           "${LUKS_KEYSLOT}"        \
      --key-file           "${LUKS_KEYFILE}"        \
      --header             "${HEADER}"              \
      luksDump "/dev/zero"

  @@MENDER/LUKS_SUDO_CMD@@                          \
  cryptsetup @@MENDER/LUKS_CRYPTSETUP_OPTS_SPECS@@  \
      --master-key-file    "${LUKS_MASTER_KEYFILE}" \
      --key-slot           "${LUKS_KEYSLOT}"        \
      --key-file           "${LUKS_KEYFILE}"        \
      --header             "${HEADER}"              \
      reencrypt --encrypt  "${DEV}" "${DM_NAME}"

  @@MENDER/LUKS_SUDO_CMD@@ cryptsetup luksClose ${DM_NAME}
}

################################################################################
function mender_luks_encrypt_image {
  local IMAGE="$1"
  local DEV_BASE=$(@@MENDER/LUKS_SUDO_CMD@@ losetup -f --show -P "${IMAGE}")
  local DEV_BOOT="${DEV_BASE}p@@MENDER_BOOT_PART_NUMBER@@"

  if   [   -z "$IMAGE" ]; then
    fatal "mender_luks_encrypt_image: missing function parameter IMAGE"
  elif [   -z "$DEV_BASE" ]; then
    fatal "mender_luks_encrypt_image: losetup failed to return valid loopback device"
  elif [ ! -b "$DEV_BOOT" ]; then
    fatal "mender_luks_encrypt_image::device($DEV_BOOT) does not exist"
  fi

  @@MENDER/LUKS_SUDO_CMD@@ mount $DEV_BOOT $BOOTDIR

  mender_luks_encrypt_part "${DEV_BASE}p@@MENDER_DATA_PART_NUMBER@@" \
                           "@@MENDER/LUKS__DATA__PART___DM_NAME@@"   \
			   "$(find $BOOTDIR -name @@MENDER/LUKS__DATA__PART___HEADER_NAME@@)"

  mender_luks_encrypt_part "${DEV_BASE}p@@MENDER_ROOTFS_PART_A_NUMBER@@" \
                           "@@MENDER/LUKS_ROOTFS_PART_A_DM_NAME@@"       \
			   "$(find $BOOTDIR -name @@MENDER/LUKS_ROOTFS_PART_A_HEADER_NAME@@)"

  mender_luks_encrypt_part "${DEV_BASE}p@@MENDER_ROOTFS_PART_B_NUMBER@@" \
                           "@@MENDER/LUKS_ROOTFS_PART_B_DM_NAME@@"       \
			   "$(find $BOOTDIR -name @@MENDER/LUKS_ROOTFS_PART_B_HEADER_NAME@@)"

  ##FIXME - can we encrypt extra (mender) partitions?

  ##############################################################################
  cleanup # make sure IMAGE is done
  log "recreating bmap: ${IMAGE}.bmap"
  rm              -f   "${IMAGE}.bmap"
  bmaptool create -o   "${IMAGE}.bmap" "${IMAGE}"
}

################################################################################
################################################################################
################################################################################
cleanup

mkdir -p $WORKDIR
mkdir -p $BOOTDIR

IMAGE_PATH="$1"

if   [   -z "$IMAGE_PATH" ]; then
  usage && fatal "missing IMAGE command line argument"
elif [ ! -d "$BOOTDIR" ]; then
           fatal "failed to create BOOTDIR: $BOOTDIR"
elif [ ! -d "$WORKDIR" ]; then
           fatal "failed to create WORKDIR: $WORKDIR"
fi

mender_luks_encrypt_image $IMAGE_PATH

################################################################################
log "successfully finished all encryption tasks"
log "$IMAGE_PATH can now be used to provision new systems: "
log "    bmaptool copy $IMAGE_PATH <DEST>"

exit 0
