#!/bin/sh
set -e

function log {
  echo "$@" >&2
}
log "$(cat /etc/mender/artifact_info): $(basename "$0") was called!"

function cleanup {
  local CMD="@@sbindir@@/mender-luks-tpm2-util.sh"
  command -v "${CMD}" && [[ -f "@@MENDER/LUKS_LEGACY_KEY_FILE@@" ]] && ${CMD} --write --pcrs none

  local CMD="@@sbindir@@/mender-luks-cryptenroll.sh"
  command -v "${CMD}" && ${CMD} -u

  return 0
}
trap cleanup EXIT

exit
