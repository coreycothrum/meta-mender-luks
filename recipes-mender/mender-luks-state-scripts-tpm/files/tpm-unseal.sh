#!/bin/sh
set -e

function log {
  echo "$@" >&2
}

function cleanup {
  @@sbindir@@/mender-luks-tpm2-util.sh --write --pcrs @@MENDER/LUKS_TPM_PCR_UPDATE_UNLOCK@@
}
trap cleanup EXIT

################################################################################
exit
