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
if ! command -v fw_printenv &> /dev/null; then
  alias fw_printenv='grub-mender-grubenv-print'
fi

UPGRADE_AV="$(fw_printenv upgrade_available | sed 's/[^=]*=//')"
BOOT_COUNT="$(fw_printenv bootcount         | sed 's/[^=]*=//')"

if [ "$BOOT_COUNT" -gt "0" ] && [ "$UPGRADE_AV" -gt "0" ]; then
  fatal "an update is already in progress; either commit or rollback before trying again"
fi

exit
