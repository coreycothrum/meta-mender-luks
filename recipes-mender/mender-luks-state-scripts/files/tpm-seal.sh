#!/bin/sh
set -e

function log {
  echo "$@" >&2
}
log "$(cat /etc/mender/artifact_info): $(basename "$0") was called!"

function cleanup {
  local CMD="@@sbindir@@/mender-luks-tpm2-util.sh"

  command -v "${CMD}" && [[ -f "@@MENDER/LUKS_LEGACY_KEY_FILE@@" ]] && ${CMD} --write --pcrs max

  return 0
}
trap cleanup EXIT

exit
