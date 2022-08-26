#!/bin/sh
set -e

function log {
  echo "$@" >&2
}
log "$(cat /etc/mender/artifact_info): $(basename "$0") was called!"

function fatal {
  log $@
  exit 1
}

################################################################################
if   systemctl --quiet is-active mender-luks-tpm-seal-on-boot.service > /dev/null 2>&1; then
  fatal "mender-luks-tpm-seal-on-boot.service is still active. Wait longer before you can update again."
elif systemctl --quiet is-failed mender-luks-tpm-seal-on-boot.service > /dev/null 2>&1; then
  fatal "mender-luks-tpm-seal-on-boot.service failed. system may be unstable."
fi

exit
