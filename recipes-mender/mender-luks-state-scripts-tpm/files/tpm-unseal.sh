#!/bin/sh
set -e

function log {
  echo "$@" >&2
}

function cleanup {
  @@sbindir@@/mender-luks-tpm2-util.sh --write --pcrs min
}
trap cleanup EXIT

################################################################################
exit
