#!/usr/bin/env bash
################################################################################
set -eu
source mender-luks-cryptenroll-functions.sh

################################################################################
CRYPTENROLL_LEGACY=$([[ "@@MENDER/LUKS_LEGACY_COMPAT@@" == "1" ]] && echo true || echo false)
CRYPTENROLL_TPM2=$([[ "@@MENDER/LUKS_CRYPTENROLL_TPM2@@" == "1" ]] && echo true || echo false)
DUMP_SLOT_INFO=false
FORCE_NEW_RECOVERY_KEY=false
SET_PASSWORD=$([[ -v NEWPASSWORD ]] && echo true || echo false)
SET_PCRS=false
WIPE_EMPTY_SLOTS=$([[ "@@MENDER/LUKS_CRYPTENROLL_PASSWORD_FORBID_EMPTY@@" == "1" ]] && echo true || echo false)
WIPE_PASSWORD_SLOTS=$([[ "@@MENDER/LUKS_CRYPTENROLL_PASSWORD@@" != "1" ]] && echo true || echo false)
WIPE_PASSWORD_ON_INIT=$([[ "@@MENDER/LUKS_CRYPTENROLL_PASSWORD_WIPE_ON_INIT@@" == "1" ]] && echo true || echo false)

################################################################################
usage() {
  echo "setup/maintain/update cryptenroll for existing LUKS partition(s)"
  echo ""
  echo "options:"
  echo "    -p       : set LUKS password"
  echo "    -r       : regen new random recovery passphrase"
  echo "    -t "N+N" :   seal TPM to supplied level"
  echo "    -u       : unseal TPM (i.e. set locking PCRs to none)"
  echo "    -v       : print LUKS slot info"
  echo "    -w       : wipe all LUKS password/passphrase slots"
  echo "    -h"
}

################################################################################
cleanup() {
  :
}
trap 'cleanup; mender_luks_cryptenroll_cleanup' EXIT

################################################################################
################################################################################
################################################################################
while getopts "hprt:uvw" opt; do
  case "${opt}" in
    h) usage
       exit
       ;;
    p) SET_PASSWORD=true
       [[ ! -v NEWPASSWORD ]] && NEWPASSWORD="$(systemd-ask-password -n "NEWPASSWORD:")"
       validate_password
       ;;
    r) FORCE_NEW_RECOVERY_KEY=true
       ;;
    t) SET_PCRS=true
       PCRS="${OPTARG}"
       ;;
    u) SET_PCRS=true
       PCRS=""
       ;;
    v) DUMP_SLOT_INFO=true
       ;;
    w) WIPE_PASSWORD_SLOTS=true
       ;;
    *) usage
       exit
       ;;
  esac
done

################################################################################
_do_task() {
  local HEADER="${HEADER}"
  local NAME="$(basename ${HEADER})"
  local RECOVERY_FILE="@@MENDER/LUKS_DATA_DIR@@/${NAME}.@@MENDER/LUKS_RECOVERY_EXT@@"
  local UNLOCK_KEY_OPT=""

  # create unlock-key-file to avoid future user interaction
  if [[ ! -f "${RECOVERY_FILE}" ]]; then
    force_new_recovery_key

    if [[ "${WIPE_PASSWORD_ON_INIT}" == true ]]; then
      WIPE_PASSWORD_SLOTS=true
    fi
    SET_PCRS=true
    PCRS=""
  elif [[ "${FORCE_NEW_RECOVERY_KEY}" == true ]]; then
    force_new_recovery_key
  fi
  local UNLOCK_KEY_OPT="--unlock-key-file=${RECOVERY_FILE}"

  ##############################################################################
  if [[ "${SET_PASSWORD}" == true ]]; then
    echo "${NAME}: enrolling/updating password"
    NEWPASSWORD="${NEWPASSWORD}" do_cryptenroll_password
  fi

  ##############################################################################
  if [[ "${WIPE_PASSWORD_SLOTS}" == true ]]; then
    echo "${NAME}: wiping all password slot(s)"
    do_cryptenroll_wipe "password"
  fi

  ##############################################################################
  if [[ "${CRYPTENROLL_LEGACY}" == true ]]; then
    echo "${NAME}: enrolling legacy key in password slot(s)"
    if [[ ! -f "${LEGACY_KEY_FILE}" ]]; then
      if   [[ -f "${RECOVERY_FILE}" ]]; then cat "${RECOVERY_FILE}" > "${LEGACY_KEY_FILE}";
      else echo -n "$(md5sum <(echo "${RANDOM}") | cut -d ' ' -f1)" > "${LEGACY_KEY_FILE}";
      fi
      chmod 600 ${LEGACY_KEY_FILE}
    fi
    NEWPASSWORD="$(cat ${LEGACY_KEY_FILE})" do_cryptenroll_password
  fi

  ##############################################################################
  if [[ "${WIPE_EMPTY_SLOTS}" == true ]]; then
    echo "${NAME}: wiping all empty slot(s)"
    do_cryptenroll_wipe "empty"
  fi

  ##############################################################################
  if [[ "${CRYPTENROLL_TPM2}" != true ]]; then
    echo "${NAME}: wiping all tpm2 slot(s)"
    do_cryptenroll_wipe "tpm2"
  elif [[ "${SET_PCRS}" == true ]]; then
    echo "${NAME}: enrolling tpm2 key sealed to PCR(s): ${PCRS}"
    do_cryptenroll_tpm2
  fi

  ##############################################################################
  if [[ "${DUMP_SLOT_INFO}" == true ]]; then
    echo "${NAME}: listing slot(s)"
    do_cryptenroll
  fi

  return 0
}

for_each_luks_header _do_task

[[ -f "${LEGACY_KEY_FILE}" && "${CRYPTENROLL_LEGACY}" != true ]] && rm -fr "${LEGACY_KEY_FILE}"

exit 0
################################################################################
