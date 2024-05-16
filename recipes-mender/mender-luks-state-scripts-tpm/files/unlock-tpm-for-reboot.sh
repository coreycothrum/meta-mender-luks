#!/bin/sh
set -e

function log {
  echo "$@" >&2
}
log "$(cat /etc/mender/artifact_info): $(basename "$0") was called!"

function cleanup {
  @@sbindir@@/mender-luks-tpm2-util.sh --write --pcrs @@MENDER/LUKS_TPM_PCR_UPDATE_UNLOCK@@
}
trap cleanup EXIT

################################################################################
exit
