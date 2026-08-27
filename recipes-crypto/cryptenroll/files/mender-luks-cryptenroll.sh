#!/usr/bin/env bash
################################################################################
set -eu
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/mender-luks-cryptsetup-functions.sh"

################################################################################
################################################################################
usage() {
  cat <<'EOF'
Usage: mender-luks-cryptenroll.sh [options]

Setup and maintain systemd-cryptenroll state for existing LUKS partition(s).

Unlock credentials are discovered automatically when needed.
Current preference order:
  1. Recovery key file for the target LUKS header.
  2. PASSWORD environment variable (if already set).
  3. systemd credential: @@MENDER/LUKS_SYSTEMD_CRYPTENROLL_PASSPHRASE_CREDENTIAL@@
  4. meta-mender-luks legacy shared key file.

Options:
  -p         Enroll a new LUKS password/passphrase.
             If NEWPASSWORD is unset, prompt interactively.
  -t N+N     Seal TPM2 keyslot to the provided PCR policy.
  -u         Unseal TPM2 keyslot (equivalent to -t "").
  -v         Print current LUKS slot information.
  -h         Show this help text.

Environment (optional):
  PASSWORD      Existing LUKS password/passphrase used for authentication.
  NEWPASSWORD   New LUKS password/passphrase to enroll.

For more information visit: https://github.com/coreycothrum/meta-mender-luks
EOF
}

DUMP_SLOT_INFO=false
SET_PCRS=false
PCRS="@@MENDER/LUKS_CRYPTENROLL_TPM2_PCRS___SEALED@@"
TPM2_FEATURE_ENABLED=$([[       "@@MENDER/LUKS_DISTRO_FEATURES_CONTAIN_TPM2@@"           == "1" ]] && echo true || echo false)
WIPE_EMPTY_SLOTS=$([[           "@@MENDER/LUKS_CRYPTENROLL_PASSWORD_FORBID_EMPTY@@"      == "1" ]] && echo true || echo false)
RANDOMIZE_PASSWORD_ON_INIT=$([[ "@@MENDER/LUKS_CRYPTENROLL_PASSWORD_RANDOMIZE_ON_INIT@@" == "1" ]] && echo true || echo false)

################################################################################
while getopts "hpt:uv" opt; do
  case "${opt}" in
    h) usage
       exit
       ;;
    p) [[ ! -v NEWPASSWORD ]] && NEWPASSWORD="$(systemd-ask-password -n "NEWPASSWORD:")"
       ;;
    t) SET_PCRS=true
       PCRS="${OPTARG}"
       ;;
    u) SET_PCRS=true
       PCRS=""
       ;;
    v) DUMP_SLOT_INFO=true
       ;;
    *) usage
       exit
       ;;
  esac
done

################################################################################
# determine the current LUKS password, then run provided command w/ PASSWORD set to it
determine_current_password() {
  local HAVE_PASSWORD_SOURCE=false

  if [[ -f "${RECOVERY_FILE:-}" ]]; then
    echo "${NAME}: using recovery key" >&2
    PASSWORD="$(cat "${RECOVERY_FILE}")"
    HAVE_PASSWORD_SOURCE=true
  elif [[ -v PASSWORD ]]; then
    echo "${NAME}: using provided PASSWORD env var" >&2
    HAVE_PASSWORD_SOURCE=true
  elif PASSWORD="$(systemd-creds --system cat @@MENDER/LUKS_SYSTEMD_CRYPTENROLL_PASSPHRASE_CREDENTIAL@@ 2>/dev/null)"; then
    echo "${NAME}: using systemd-creds: @@MENDER/LUKS_SYSTEMD_CRYPTENROLL_PASSPHRASE_CREDENTIAL@@" >&2
    HAVE_PASSWORD_SOURCE=true
  elif [[ -f "${LEGACY_FILE:-}" ]]; then
    echo "${NAME}: using legacy key" >&2
    PASSWORD="$(cat "${LEGACY_FILE}")"
    HAVE_PASSWORD_SOURCE=true
  else
    PASSWORD=""
  fi

  if [[ "${HAVE_PASSWORD_SOURCE}" != true ]]; then
    echo "${NAME:-cryptenroll}: failed to determine current LUKS password/passphrase" >&2
    return 1
  fi
  return 0
}

################################################################################
# wrapper around systemd-cryptenroll that ensures the current password is determined and passed correctly
do_systemd_cryptenroll() {
  local PASSWORD
  determine_current_password
  PASSWORD="${PASSWORD-}" NEWPASSWORD="${NEWPASSWORD-}" systemd-cryptenroll "${HEADER}" "${@}"
}

################################################################################
# any device marked for LUKS2 reencryption is required to be completed before proceeding with other cryptenroll operations
_do_reencrypt() {
  local PASSWORD
  local REENCRYPT_OPTIONS="--resume-only"
  determine_current_password
  luks_reencrypt
}
for_each_in_crypttab _do_reencrypt

################################################################################
# handle LUKS key maintenance for each LUKS header
_do_luks_key_maintenance() {
  set -eu
  local HEADER="${HEADER}"
  local NAME="$(basename "${HEADER}")"
  local LEGACY_FILE="@@MENDER/LUKS_LEGACY_KEY_FILE@@"
  local RECOVERY_FILE="@@MENDER/LUKS_DATA_DIR@@/${NAME}.@@MENDER/LUKS_RECOVERY_EXT@@"

  ##############################################################################
  # LEGACY_FILE is a passphrase shared between all LUKS partitions
  # this is for backwards compat w/ systems deployed prior to this refactor
  if [[ ! -f "${LEGACY_FILE}" ]]; then
    local PASSWORD
    determine_current_password
    [[ "${RANDOMIZE_PASSWORD_ON_INIT}" == true ]] && PASSWORD="$(openssl rand -hex 16)"
    echo "${NAME}: generating new legacy key" >&2
    install -m 600 -D <(echo "${PASSWORD}") "${LEGACY_FILE}"
  fi
  if [[ -v NEWPASSWORD ]]; then
    echo "${NAME}: NEWPASSWORD is overwriting existing legacy passphrase" >&2
    install -m 600 -D <(echo "${NEWPASSWORD}") "${LEGACY_FILE}"
  fi
  if [[ -f "${LEGACY_FILE}" ]]; then
    echo "${NAME}: enrolling new/legacy passphrase" >&2
    NEWPASSWORD="$(cat "${LEGACY_FILE}")"
    do_systemd_cryptenroll --wipe-slot=password --password
  fi
 
  ##############################################################################
  # create recovery keys. Will later be used to unlock the LUKS device for maintenance
  if [[ ! -f "${RECOVERY_FILE}" ]]; then
    echo "${NAME}: enrolling recovery key" >&2
    install -m 600 -D <(do_systemd_cryptenroll --wipe-slot=recovery --recovery-key) "${RECOVERY_FILE}"
  fi

  ##############################################################################
  local SET_PCRS="${SET_PCRS:-false}"
  if [[ "${TPM2_FEATURE_ENABLED}" == true ]]; then
    if ! do_systemd_cryptenroll | grep -qi "tpm2"; then
      echo "${NAME}: no TPM2 slots enrolled; enrolling TPM2 policy" >&2
      SET_PCRS=true
    fi
    if [[ "${SET_PCRS}" == true ]]; then
      echo "${NAME}: enrolling TPM w/ PCRS: ${PCRS}" >&2
      do_systemd_cryptenroll --wipe-slot=tpm2 --tpm2-pcrs="${PCRS}" --tpm2-device=@@MENDER/LUKS_TPM2_DEVICE@@
    fi
  fi

  ##############################################################################
  [[ "${WIPE_EMPTY_SLOTS}" == true ]] && echo "${NAME}: wiping empty slots" >&2 && do_systemd_cryptenroll --wipe-slot=empty
  [[ "${DUMP_SLOT_INFO}"   == true ]]                                           && do_systemd_cryptenroll

  return 0
}
for_each_luks_header _do_luks_key_maintenance

exit 0