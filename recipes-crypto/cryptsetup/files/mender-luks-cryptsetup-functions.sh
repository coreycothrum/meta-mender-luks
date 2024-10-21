#!/usr/bin/env bash
################################################################################
set -eu

export TMPDIR="${TMPDIR:-"/tmp"}/mender-luks-cryptsetup-utils"
if [[ ! -d "${TMPDIR}" ]]; then
  mkdir -p "${TMPDIR}"
fi
export WORKDIR="$(mktemp --directory)"

################################################################################
fatal() {
  echo "aborting: $@"
  exit 1
}

################################################################################
do_sudo() {
  PSEUDO_UNLOAD=1 sudo env PATH=${PATH} PSEUDO_UNLOAD=1 "$@"
}

################################################################################
mender_luks_cryptsetup_cleanup() {
  set +e
    unset    PASSWORD
    unset NEWPASSWORD

    if [[ -d "${WORKDIR}" ]]; then
      find   "${WORKDIR}" -type f -exec shred -fu {} \;
      rm -fr "${WORKDIR}"
    fi

    sync
  set -eu
}

################################################################################
################################################################################
################################################################################
for_each_in_crypttab() {
  local CMD="${@}"

  local CRYPTTAB="${CRYPTTAB:-"@@sysconfdir@@/crypttab"}"
  [[ ! -f "${CRYPTTAB}" ]] && fatal "${CRYPTTAB} does not exist"

  local IFS=$'\n'
  for ENTRY in $(grep --line-buffered "luks" "${CRYPTTAB}"); do
    if [[ "${ENTRY}" =~ ^[[:space:]]*([^[:space:]]*)[[:space:]]+([^[:space:]]*).*[[:space:]]+([^[:space:]]*)$ ]]; then
      if [[ "${#BASH_REMATCH[@]}" == 4 ]]; then
        local NAME="${BASH_REMATCH[1]}"
        local DEV="${BASH_REMATCH[2]}"
        local OPTS="${BASH_REMATCH[3]}"

        if [[ "${OPTS}" =~ ^.*header=([^[:space:]]*)[[:space:],]*$ ]]; then
          if [[ "${#BASH_REMATCH[@]}" == 2 ]]; then
            local HEADER="${BASH_REMATCH[1]}"
          fi
        fi
      eval "${CMD}"
      fi
    fi
  done

  return 0
}

################################################################################
for_each_luks_header() {
  local CMD="${@}"
  local HEADER_DIR="${HEADER_DIR:-"@@MENDER/LUKS_HEADER_DIR@@"}"

  local IFS=$'\n'
  for HEADER in $(find "${HEADER_DIR}" -type f -iname "*.@@MENDER/LUKS_HEADER_EXT@@"); do
    eval "${CMD}"
  done

  return 0
}

################################################################################
################################################################################
################################################################################
luks_close() {
  local NAME="$1"
  eval do_sudo cryptsetup --batch-mode --type luks2 close ${NAME}
}

################################################################################
luks_open() {
  local NAME="$1"
  local DEV="$2"
  local HEADER="$3"
  local PASSWORD="${PASSWORD}"

  [[ ! -b "${DEV}"    ]] && fatal "${DEV}    does not exist"
  [[ ! -f "${HEADER}" ]] && fatal "${HEADER} does not exist"

  local KEY_FILE="$(mktemp --tmpdir=${WORKDIR})" && echo -n "${PASSWORD}" > "${KEY_FILE}"

  eval do_sudo cryptsetup --batch-mode --type luks2 \
    --header      "${HEADER}"                       \
    --key-file    "${KEY_FILE}"                     \
    open "${DEV}" "${NAME}"
}

################################################################################
luks_change_key() {
  local NAME="$1"
  local DEV="$2"
  local HEADER="$3"
  local PASSWORD="${PASSWORD}"
  local NEWPASSWORD="${NEWPASSWORD}"

  [[ ! -b "${DEV}"    ]] && fatal "${DEV}    does not exist"
  [[ ! -f "${HEADER}" ]] && fatal "${HEADER} does not exist"

  local OLD_KEY_FILE="$(mktemp --tmpdir=${WORKDIR})" && echo -n    "${PASSWORD}" > "${OLD_KEY_FILE}"
  local NEW_KEY_FILE="$(mktemp --tmpdir=${WORKDIR})" && echo -n "${NEWPASSWORD}" > "${NEW_KEY_FILE}"

  echo "${NAME}: updating LUKS password"

  eval do_sudo cryptsetup --batch-mode --type luks2 \
    --force-password                                \
    --header               "${HEADER}"              \
    --key-file             "${OLD_KEY_FILE}"        \
    luksChangeKey "${DEV}" "${NEW_KEY_FILE}"
}

################################################################################
# 1st time (no/missing header): encrypt/format luks
# subsequent run(s): reencrypt
luks_reencrypt() {
  local NAME="$1"
  local DEV="$2"
  local HEADER="$3"
  local PASSWORD="${PASSWORD}"

  [[ ! -b "${DEV}" ]] && fatal "${DEV} does not exist"

  local KEY_FILE="$(mktemp --tmpdir=${WORKDIR})" && echo -n "${PASSWORD}" > "${KEY_FILE}"
  local ENCRYPT_CMD=""
  local OFFLINE_CMD=""

  if [[ ! -f "${HEADER}" ]]; then
    echo "${NAME}: encrypting new LUKS partition (may take awhile)"
    local ENCRYPT_CMD="--encrypt"
  else
    echo "${NAME}: reencrypting existing LUKS partition (may take awhile)"
    local ENCRYPT_CMD=""
  fi

  if do_sudo cryptsetup --header "${HEADER}" status "${NAME})"; then
    echo "${NAME}:  online cryptsetup-reencrypt"
    local OFFLINE_CMD=""
  else
    echo "${NAME}: offline cryptsetup-reencrypt"
    local OFFLINE_CMD="--force-offline-reencrypt"
  fi

  eval time do_sudo cryptsetup --batch-mode --type luks2 \
    --force-password                                     \
    --header   "${HEADER}"                               \
    --key-file "${KEY_FILE}"                             \
    --progress-frequency 30                              \
    reencrypt "${ENCRYPT_CMD}" "${OFFLINE_CMD}" "${DEV}"
}

################################################################################
