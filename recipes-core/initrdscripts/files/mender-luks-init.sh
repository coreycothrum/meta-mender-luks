#!/bin/sh
################################################################################
PATH=$PATH:/sbin:/bin:/usr/sbin:/usr/bin

mkdir -p /dev  ; mount -n -t devtmpfs devtmpfs /dev
mkdir -p /proc ; mount -n -t proc     proc     /proc
mkdir -p /run  ; mount -n -t tmpfs    tmpfs    /run
mkdir -p /sys  ; mount -n -t sysfs    sysfs    /sys

mknod /dev/console c 5 1
mknod /dev/null    c 1 3
mknod /dev/zero    c 1 5

################################################################################
CONSOLE="/dev/console"

MNT_DIR="/tmp"

ROOT_MNT="$MNT_DIR/root"
ROOT_DEV=""

BOOT_MNT="$MNT_DIR@@MENDER_BOOT_PART_MOUNT_LOCATION@@"
BOOT_DEV=@@MENDER_BOOT_PART@@

DATA_MNT="$MNT_DIR@@MENDER_DATA_PART_MOUNT_LOCATION@@"
DATA_DEV=@@MENDER_DATA_PART@@

if @@MENDER/LUKS_PARTUUID_IS_USED@@; then
    BOOT_DEV=$(findfs PARTUUID="$(basename @@MENDER_BOOT_PART@@)")
    DATA_DEV=$(findfs PARTUUID="$(basename @@MENDER_DATA_PART@@)")
    MENDER_ROOTFS_PART_A=PARTUUID="$(basename @@MENDER_ROOTFS_PART_A@@)"
    MENDER_ROOTFS_PART_B=PARTUUID="$(basename @@MENDER_ROOTFS_PART_B@@)"
    ROOT_A_DEV=$(findfs $MENDER_ROOTFS_PART_A)
    ROOT_B_DEV=$(findfs $MENDER_ROOTFS_PART_B)
else
    MENDER_ROOTFS_PART_A=@@MENDER_ROOTFS_PART_A@@
    MENDER_ROOTFS_PART_B=@@MENDER_ROOTFS_PART_B@@
    ROOT_A_DEV=$MENDER_ROOTFS_PART_A
    ROOT_B_DEV=$MENDER_ROOTFS_PART_B
fi


ROOT_DM_NAME=""
ROOT_HEADER=""

DATA_DM_NAME=@@MENDER/LUKS__DATA__PART___DM_NAME@@
DATA_HEADER=@@MENDER/LUKS__DATA__PART___HEADER@@

LUKS_KEY="$MNT_DIR/@@MENDER/LUKS_KEY_FILE@@"

################################################################################
debug_shell() {
  log "exitting to debug shell"
  exec sh <$CONSOLE >$CONSOLE 2>$CONSOLE
}

log() {
  echo "$@" >$CONSOLE
}

fatal() {
  echo "$@" >$CONSOLE
  echo      >$CONSOLE
  exit 1
}

################################################################################
read_args() {
  [ -z "${CMDLINE+x}" ] && CMDLINE=`cat /proc/cmdline`
  for arg in $CMDLINE; do
    optarg=`expr "x$arg" : 'x[^=]*=\(.*\)' || echo ''`
    case $arg in
      root=*)
        ROOT_DEV=$optarg ;;
    esac
  done
}

map_root_dev() {
  # determine which rootfs to mount
  case $ROOT_DEV in
    $MENDER_ROOTFS_PART_A)
      ROOT_DM_NAME=@@MENDER/LUKS_ROOTFS_PART_A_DM_NAME@@
      ROOT_HEADER=@@MENDER/LUKS_ROOTFS_PART_A_HEADER@@
      ROOT_DEV=$ROOT_A_DEV;;
    $MENDER_ROOTFS_PART_B)
      ROOT_DM_NAME=@@MENDER/LUKS_ROOTFS_PART_B_DM_NAME@@
      ROOT_HEADER=@@MENDER/LUKS_ROOTFS_PART_B_HEADER@@
      ROOT_DEV=$ROOT_B_DEV;;
    *)
      fatal "unknown root=$ROOT_DEV"
  esac
}

mender_luks_encrypt_part() {
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

  local LUKS_KEYSLOT="@@MENDER/LUKS_PRIMARY_KEY_SLOT@@"

  # Assume if type is recognized, this means encryption was not yet started
  if blkid $DEV | grep "TYPE=" 2>&1 >/dev/null; then
    log "Initializing encryption on $DEV"

    echo -n "@@MENDER/LUKS_PASSWORD@@" | cryptsetup @@MENDER/LUKS_CRYPTSETUP_OPTS_SPECS@@  \
      --key-slot           "${LUKS_KEYSLOT}"        \
      --key-file           -                        \
      --header             "${HEADER}"              \
      reencrypt --encrypt  "${DEV}" "${DM_NAME}"

    cryptsetup luksClose ${DM_NAME}
  else
    log "$DEV is already encrypted"
  fi
}

unlock_luks_partitions() {
  local TPM_READ_CMD="mender-luks-tpm2-util.sh --read"
  local RETRY_COUNT="1 2"
  local CMD_PREPEND=""
  local KEY_VS_PROMPT=""

  # read key from TPM, if available
  if eval $TPM_READ_CMD 2>&1 >/dev/null; then
    local KEY_VS_PROMPT="--key-file=-"
    local CMD_PREPEND="$TPM_READ_CMD |"
  fi

  # unlock, mount rootfs partition
  for try in $RETRY_COUNT:
  do
    local CMD="$CMD_PREPEND cryptsetup luksOpen                             \
                                       @@MENDER/LUKS_CRYPTSETUP_OPTS_BASE@@ \
                                       --header $MNT_DIR/$ROOT_HEADER       \
                                       $KEY_VS_PROMPT                       \
                                       $ROOT_DEV                            \
                                       $ROOT_DM_NAME                        "

    # log "$CMD"
    # debug_shell

    if eval $CMD; then
      ROOT_DEV="@@MENDER/LUKS_DM_MAPPER_DIR@@/$ROOT_DM_NAME"
      return 0
    fi

    log "!!! Failed to unlock LUKS partition $ROOT_DEV"

    if [ ! -z "$KEY_VS_PROMPT" ]; then
      log "stored keyfile failed, falling back to manual passphrase input"
      local CMD_PREPEND=""
      local KEY_VS_PROMPT=""
    fi
  done

  fatal "!!! Failed to unlock LUKS partition $ROOT_DEV"

  return 1
}

################################################################################
mkdir -p           $BOOT_MNT
mount    $BOOT_DEV $BOOT_MNT

# Ensure we have enough entropy on case we have yet to encrypt all partitions
dd if=/dev/random of=/dev/null bs=16 count=1 status=none

# The following encryption commands will only encrypt the partition if it is not yet encrypted
mender_luks_encrypt_part $DATA_DEV \
		   "@@MENDER/LUKS__DATA__PART___DM_NAME@@"   \
		   "$(find $BOOT_MNT -name @@MENDER/LUKS__DATA__PART___HEADER_NAME@@)"

mender_luks_encrypt_part $ROOT_A_DEV \
		   "@@MENDER/LUKS_ROOTFS_PART_A_DM_NAME@@"       \
		   "$(find $BOOT_MNT -name @@MENDER/LUKS_ROOTFS_PART_A_HEADER_NAME@@)"

mender_luks_encrypt_part $ROOT_B_DEV \
		   "@@MENDER/LUKS_ROOTFS_PART_B_DM_NAME@@"       \
		   "$(find $BOOT_MNT -name @@MENDER/LUKS_ROOTFS_PART_B_HEADER_NAME@@)"

read_args && map_root_dev && unlock_luks_partitions

mkdir -p           $ROOT_MNT
mount    $ROOT_DEV $ROOT_MNT

cd                 $ROOT_MNT
exec switch_root   $ROOT_MNT /sbin/init
