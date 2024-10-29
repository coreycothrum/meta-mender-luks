#!/usr/bin/env bash
################################################################################
set -eu
source mender-luks-cryptsetup-functions.sh

################################################################################
LEGACY_KEY_FILE="@@MENDER/LUKS_LEGACY_KEY_FILE@@"
PCRS="@@MENDER/LUKS_CRYPTENROLL_TPM2_SEALED_PCRS@@"

################################################################################
mender_luks_cryptenroll_cleanup() {
  mender_luks_cryptsetup_cleanup
}

################################################################################
do_cryptenroll() {
  eval systemd-cryptenroll ${HEADER} ${UNLOCK_KEY_OPT} ${@}
}

################################################################################
do_cryptenroll_wipe() {
  do_cryptenroll --wipe-slot="${1}"
}

################################################################################
#    PASSWORD
# NEWPASSWORD
do_cryptenroll_password() {
  do_cryptenroll --wipe-slot=password --password
}

validate_password() {
  if [[ -z "${NEWPASSWORD}" ]]; then
     [[ "@@MENDER/LUKS_CRYPTENROLL_PASSWORD_FORBID_EMPTY@@"   == "1" ]] \
     && fatal "MENDER/LUKS_CRYPTENROLL_PASSWORD_FORBID_EMPTY"
  else
     [[ "@@MENDER/LUKS_CRYPTENROLL_PASSWORD_ENFORCE_STRONG@@" == "1" ]]          \
     && ! grep "OK" <(echo -n "${NEWPASSWORD}" | cracklib-check) >/dev/null 2>&1 \
     && fatal "MENDER/LUKS_CRYPTENROLL_PASSWORD_ENFORCE_STRONG"
  fi

  return 0
}

################################################################################
do_cryptenroll_tpm2() {
  do_cryptenroll --wipe-slot=tpm2 --tpm2-pcrs="${PCRS}" --tpm2-device=@@MENDER/LUKS_TPM2_DEVICE@@
}

################################################################################
force_new_recovery_key() {
  local KEY_FILE="$(mktemp --tmpdir=${WORKDIR})"
  local SYSTEMD_CRED_HEADER="systemd-creds --system cat ${NAME}"
  local SYSTEMD_CRED_LEGACY="systemd-creds --system cat legacy"
  local UNLOCK_KEY_OPT=""

  if   eval "${SYSTEMD_CRED_HEADER}" >/dev/null 2>&1 ; then cat      <(eval "${SYSTEMD_CRED_HEADER}") > ${KEY_FILE};
  elif eval "${SYSTEMD_CRED_LEGACY}" >/dev/null 2>&1 ; then cat      <(eval "${SYSTEMD_CRED_LEGACY}") > ${KEY_FILE};
  elif [[ -f "${RECOVERY_FILE}"   ]]                 ; then cat       "${RECOVERY_FILE}"              > ${KEY_FILE};
  elif [[ -v    PASSWORD          ]]                 ; then echo -n   "${PASSWORD}"                   > ${KEY_FILE};
  elif [[ -f "${LEGACY_KEY_FILE}" ]]                 ; then cat       "${LEGACY_KEY_FILE}"            > ${KEY_FILE};
  else                                                      rm   -fr                                    ${KEY_FILE};
  fi

  if [[   -f "${KEY_FILE}" ]]; then
    chmod 600 ${KEY_FILE}
    local UNLOCK_KEY_OPT="--unlock-key-file=${KEY_FILE}"
  fi

  install -m 600 -D <(do_cryptenroll --wipe-slot=recovery --recovery-key | tr --delete '\n') "${RECOVERY_FILE}"
  install -m 600 -D                                                                          "${RECOVERY_FILE}" "@@MENDER/LUKS_SYSTEMD_INITRD_CREDENTIALS_DIR@@/${NAME}"

  [[ ! -f "${RECOVERY_FILE}" ]] && fatal "${NAME}: failed to enroll recovery key"

  return 0
}

################################################################################
