#!/bin/sh
set -e

log() {
  echo "$@" >&2
}

cleanup() {
  CMD="@sbindir@@/mender-luks-cryptenroll.sh"
  if [ -x "${CMD}" ]; then                           "${CMD}" -t "@@MENDER/LUKS_CRYPTENROLL_TPM2_PCRS_UNSEALED@@"
  else chroot @@MENDER/LUKS_ROOT_CANDIDATE_MNT_DIR@@ "${CMD}" -t "@@MENDER/LUKS_CRYPTENROLL_TPM2_PCRS_UNSEALED@@"
  fi
}
trap cleanup EXIT

################################################################################
exit
