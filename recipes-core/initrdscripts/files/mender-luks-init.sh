#!/bin/bash
################################################################################
CONSOLE="/dev/console"
PATH=$PATH:/sbin:/bin:/usr/sbin:/usr/bin

mkdir -p /dev  ; mount -n -t devtmpfs devtmpfs /dev
mkdir -p /proc ; mount -n -t proc     proc     /proc
mkdir -p /run  ; mount -n -t tmpfs    tmpfs    /run
mkdir -p /sys  ; mount -n -t sysfs    sysfs    /sys

mknod /dev/console c 5 1
mknod /dev/null    c 1 3
mknod /dev/zero    c 1 5

ln -s /proc/self/fd /dev/fd

exec <$CONSOLE >$CONSOLE 2>$CONSOLE

################################################################################
fatal() {
  echo "$@" && echo ""
  exit 1
}

################################################################################
MNT_DIR="/tmp"

ROOT_MNT="$MNT_DIR/root"
ROOT_DEV=""

BOOT_MNT="$MNT_DIR@@MENDER_BOOT_PART_MOUNT_LOCATION@@"
BOOT_DEV=@@MENDER_BOOT_PART@@

DATA_MNT="$MNT_DIR@@MENDER_DATA_PART_MOUNT_LOCATION@@"
DATA_DEV=@@MENDER_DATA_PART@@

if [[ "@@MENDER/LUKS_PARTUUID_IS_USED@@" == "1" ]]; then
  BOOT_DEV=$(findfs PARTUUID="$(basename @@MENDER_BOOT_PART@@)")
  # This is currently ununsed
  DATA_DEV=$(findfs PARTUUID="$(basename @@MENDER_DATA_PART@@)")
fi

ROOT_DM_NAME=""
ROOT_HEADER=""

DATA_DM_NAME=@@MENDER/LUKS__DATA__PART___DM_NAME@@
DATA_HEADER=@@MENDER/LUKS__DATA__PART___HEADER@@

################################################################################
read_args() {
  [[ -z "${CMDLINE+x}" ]] && CMDLINE=`cat /proc/cmdline`
  for arg in $CMDLINE; do
    optarg=`expr "x$arg" : 'x[^=]*=\(.*\)' || echo ''`
    case $arg in
      root=*)
        ROOT_DEV=$optarg ;;
    esac
  done
}

# determine which rootfs to mount
map_root_dev() {
  if [[ "@@MENDER/LUKS_PARTUUID_IS_USED@@" == "1" ]]; then
    MENDER_ROOTFS_PART_A=PARTUUID="$(basename @@MENDER_ROOTFS_PART_A@@)"
    MENDER_ROOTFS_PART_B=PARTUUID="$(basename @@MENDER_ROOTFS_PART_B@@)"
  else
    MENDER_ROOTFS_PART_A=@@MENDER_ROOTFS_PART_A@@
    MENDER_ROOTFS_PART_B=@@MENDER_ROOTFS_PART_B@@
  fi

  case $ROOT_DEV in
    $MENDER_ROOTFS_PART_A)
      ROOT_DM_NAME=@@MENDER/LUKS_ROOTFS_PART_A_DM_NAME@@
      ROOT_HEADER=@@MENDER/LUKS_ROOTFS_PART_A_HEADER@@
      ;;
    $MENDER_ROOTFS_PART_B)
      ROOT_DM_NAME=@@MENDER/LUKS_ROOTFS_PART_B_DM_NAME@@
      ROOT_HEADER=@@MENDER/LUKS_ROOTFS_PART_B_HEADER@@
      ;;
    *)
      fatal "unknown root=$ROOT_DEV"
  esac

  if [[ "@@MENDER/LUKS_PARTUUID_IS_USED@@" == "1" ]]; then
    ROOT_DEV=$(findfs $ROOT_DEV)
  fi
}

unlock_luks_partitions() {
  local KEY_FILE="@@MENDER/LUKS_SYSTEMD_INITRD_CREDENTIALS_DIR@@/legacy"
  local TPM_UTIL="mender-luks-tpm2-util.sh"

  install -m 600 -D /dev/null "${KEY_FILE}"

  if command -v "${TPM_UTIL}" 2>&1 >/dev/null; then
    echo -n "$(${TPM_UTIL} --read)" > "${KEY_FILE}"
  fi

  for IDX in {1..3}; do
    eval cryptsetup --header "$MNT_DIR/$ROOT_HEADER"          \
               --key-file="${KEY_FILE}"                       \
               luksOpen $ROOT_DEV $ROOT_DM_NAME               \
    && ROOT_DEV="@@MENDER/LUKS_DM_MAPPER_DIR@@/$ROOT_DM_NAME" \
    && return 0

    echo "!!! ${ROOT_DEV}: try $IDX to unlock LUKS partition FAILED !!!"
    read -sp "${ROOT_DEV} current password:" && echo -n "${REPLY}" > "${KEY_FILE}"
  done

  fatal "!!! $ROOT_DEV: failed to unlock LUKS partition !!!"
}

################################################################################
mkdir -p           $BOOT_MNT
mount    $BOOT_DEV $BOOT_MNT

read_args && map_root_dev && unlock_luks_partitions

mkdir -p           $ROOT_MNT
mount    $ROOT_DEV $ROOT_MNT

cd                 $ROOT_MNT
exec switch_root   $ROOT_MNT /sbin/init
