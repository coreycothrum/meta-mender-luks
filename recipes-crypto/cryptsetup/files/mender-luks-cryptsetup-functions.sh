#!/usr/bin/env bash
################################################################################
set -u

export TMPDIR="${TMPDIR:-"/tmp"}/mender-luks-cryptsetup"
if [[ ! -d "${TMPDIR}" ]]; then
  mkdir -p "${TMPDIR}"
fi

################################################################################
# print message and abort
fatal() {
  echo "aborting: $@" >&2
  exit 1
}

################################################################################
# execute command with sudo privileges
do_sudo() {
  if [[ ${EUID} -eq 0 ]]; then
    "$@"
  else
    sudo -n env PATH="${PATH}" PSEUDO_UNLOAD=1 "$@"
  fi
}

################################################################################
# detect whether a LUKS header has a pending reencryption keyslot
# output: "true" if a reencryption keyslot is pending, "false" otherwise
_is_reencrypt_pending() {
  [[ ! -f "${HEADER}" ]] && fatal "${HEADER} does not exist"
  local METADATA_JSON="$(do_sudo cryptsetup luksDump --dump-json-metadata "${HEADER}" 2>/dev/null)"
  printf "%s\n" "$(printf "%s\n" "${METADATA_JSON}" | jq -r 'any(.keyslots[]?; .type=="reencrypt")' 2>/dev/null)"
}

################################################################################
# source each entry in the crypttab and execute the given command/function for each LUKS device
# Environment variables available for the command/function:
#   NAME   : name (dm mapper) of the LUKS device
#   DEV    : device path of the LUKS device
#   HEADER : path to the LUKS header file
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
        local HEADER=""

        if [[ "${OPTS}" =~ ^.*header=([^[:space:]]*)[[:space:],]*$ ]]; then
          if [[ "${#BASH_REMATCH[@]}" == 2 ]]; then
            HEADER="${BASH_REMATCH[1]}"
            if [[ "${HEADER}" == *:* ]]; then
              HEADER="@@MENDER_BOOT_PART_MOUNT_LOCATION@@/${HEADER%%:*}"
            fi
          fi
        fi
      eval "${CMD}"
      fi
    fi
  done

  return 0
}

################################################################################
# execute the given command/function for each LUKS header file in $HEADER_DIR (or default location)
# Environment variables available for the command/function:
#   HEADER : path to the LUKS header file
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
# change the LUKS password for the given device
# required environment variables:
#   NAME       : name (dm mapper) of the LUKS device
#   DEV        : device path of the LUKS device
#   HEADER     : path to the LUKS header file
#   PASSWORD   : current LUKS password
#   NEWPASSWORD: new LUKS password
luks_change_key() {
  [[ ! -b "${DEV}"    ]] && fatal "${DEV}    does not exist"
  [[ ! -f "${HEADER}" ]] && fatal "${HEADER} does not exist"

  echo "${NAME}: executing cryptsetup luksChangeKey" >&2

  if [[ "$(_is_reencrypt_pending)" == *"true"* ]]; then
    echo "${NAME:-DEV}: reencryption pending; cannot luksChangeKey" >&2
    return 0
  fi

  do_sudo env \
    HEADER="${HEADER}" \
    DEV="${DEV}" \
    PASSWORD="${PASSWORD}" \
    NEWPASSWORD="${NEWPASSWORD:-${PASSWORD}}" \
    bash -c '
      cryptsetup --type luks2 \
        --force-password \
        --header "${HEADER}" \
        --key-file <(printf "%s" "${PASSWORD}") \
        luksChangeKey "${DEV}" <(printf "%s" "${NEWPASSWORD}")
    '  || return $?
  sync

  return 0
}

################################################################################
# re-encrypt the given LUKS device with the provided options
# required environment variables:
#   NAME              : name (dm mapper) of the LUKS device
#   DEV               : device path of the LUKS device
#   HEADER            : path to the LUKS header file
#   PASSWORD          : current LUKS password
#   REENCRYPT_OPTIONS : options for the re-encryption process/command
luks_reencrypt() {
  [[ ! -b "${DEV}"    ]] && fatal "${DEV}    does not exist"
  [[ ! -f "${HEADER}" ]] && fatal "${HEADER} does not exist"

  local PENDING_REENCRYPT="$(_is_reencrypt_pending)"
  if   [[ "${PENDING_REENCRYPT}" == *"false"* && "${REENCRYPT_OPTIONS:-}" == *"--resume-only"* ]]; then
    echo "${NAME:-DEV}: no pending reencryption; --resume-only is a noop" >&2
    return 0
  elif [[ "${PENDING_REENCRYPT}" == *"true"*  && "${REENCRYPT_OPTIONS:-}" == *"--init-only"*   ]]; then
    echo "${NAME:-DEV}: reencryption already pending; --init-only is a noop" >&2
    return 0
  fi
  echo "${NAME:-DEV}: executing cryptsetup-reencrypt reencrypt ${REENCRYPT_OPTIONS:-}" >&2

  time do_sudo env \
  HEADER="${HEADER}" \
  DEV="${DEV}" \
  PASSWORD="${PASSWORD}" \
  PROGRESS_FREQUENCY="${PROGRESS_FREQUENCY:-30}" \
  REENCRYPT_OPTIONS="${REENCRYPT_OPTIONS:-}" \
  bash -c '
    cryptsetup --type luks2 \
      @@MENDER/LUKS_CRYPTSETUP_REENCRYPT_OPTIONS@@ \
      --force-password \
      --header "${HEADER}" \
      --key-file <(printf "%s" "${PASSWORD}") \
      --progress-frequency "${PROGRESS_FREQUENCY}" \
      reencrypt ${REENCRYPT_OPTIONS} "${DEV}"
  ' || return $?
  sync

  return 0
}
