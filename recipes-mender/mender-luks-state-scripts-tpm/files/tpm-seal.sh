#!/bin/sh
set -e

function log {
  echo "$@" >&2
}

function cleanup {
  @@sbindir@@/mender-luks-tpm2-util.sh --write --pcrs max
}
trap cleanup EXIT

################################################################################
exit
