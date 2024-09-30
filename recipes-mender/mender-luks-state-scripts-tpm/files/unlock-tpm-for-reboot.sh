#!/bin/sh
set -e

function log {
  echo "$@" >&2
}
log "$(cat /etc/mender/artifact_info): $(basename "$0") was called!"

function cleanup {
  if command -v @@sbindir@@/mender-luks-tpm2-util.sh; then
    log "$(cat /etc/mender/artifact_info): mender-luks-tpm2-util.sh"
             @@sbindir@@/mender-luks-tpm2-util.sh   --write --pcrs @@MENDER/LUKS_TPM_PCR_UPDATE_UNLOCK@@
  fi

  if command -v @@sbindir@@/mender-luks-cryptenroll.sh; then
    log "$(cat /etc/mender/artifact_info): mender-luks-cryptenroll.sh"
             @@sbindir@@/mender-luks-cryptenroll.sh -u
  fi
}
trap cleanup EXIT

################################################################################
exit
