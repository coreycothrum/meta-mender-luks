#!/usr/bin/env bash
set -eu

function usage() {
  echo "setup/maintain/update cryptenroll for LUKS partitions"
  echo ""
  echo "options:"
  echo "    -p <password> : set LUKS password"
  echo "    -u            : unseal TPM (i.e. set locking PCRs to none)"
  echo "    -v            : print LUKS slot info"
  echo "    -w            : wipe all LUKS password/passphrase slots"
  echo "    -h"
  :
}

function cleanup {
  find @@MENDER/LUKS_DATA_DIR@@ -iname *.t*mp -exec shred -fu {} \;
}
trap cleanup EXIT

NEW_PASSWORD=""
PCRS="@@MENDER/LUKS_CRYPTENROLL_TPM2_SEALED_PCRS@@"
DUMP_SLOT_INFO=false
WIPE_PASSWORD_SLOTS=false

while getopts "hp:uvw" opt; do
  case ${opt} in
    h) usage
       exit
       ;;
    p) NEW_PASSWORD=$(echo -n "${OPTARG}" | tr --delete '\n')
       NEW_PASSWORD_CHECK=$(echo -n "$NEW_PASSWORD" | cracklib-check)
       if ! grep "OK" <(echo -n "$NEW_PASSWORD_CHECK"); then
         echo "$NEW_PASSWORD_CHECK"
         echo "$NEW_PASSWORD is too weak; aborting"
	 exit -1
       fi
       ;;
    u) PCRS=""
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
################################################################################
################################################################################
for HEADER in @@MENDER/LUKS_HEADER_DIR@@/*.luks; do [ -e "$HEADER" ] || continue
  BASENAME="$(basename $HEADER)"
  LEGACY_KEY_FILE="@@MENDER/LUKS_KEY_FILE@@"
  RECOVERY_FILE="@@MENDER/LUKS_DATA_DIR@@/$BASENAME.recovery"
  CRYPTENROLL_CMD="systemd-cryptenroll $HEADER --unlock-key-file=$RECOVERY_FILE"

  ##############################################################################
  # need unlock-key-file avoid user interaction w/ systemd-cryptenroll
  if [ ! -f $RECOVERY_FILE ]; then
    echo "$(basename $HEADER): creating recovery key"

    mkdir -p                                                         $(dirname $RECOVERY_FILE)
    if [ -f $LEGACY_KEY_FILE ]; then cat                    $LEGACY_KEY_FILE > $RECOVERY_FILE
    else                             echo -n "@@MENDER/LUKS_INIT_PASSWORD@@" > $RECOVERY_FILE
    fi
    chmod 600                                                                  $RECOVERY_FILE

    TMP_KEY_FILE=$(mktemp $RECOVERY_FILE.XXXX.temp)

    $CRYPTENROLL_CMD --wipe-slot=recovery --recovery-key | tr --delete '\n' > $TMP_KEY_FILE
    chmod 600                                                                 $TMP_KEY_FILE
    cp                                                                        $TMP_KEY_FILE $RECOVERY_FILE

    if [[ "@@MENDER/LUKS_CRYPTENROLL_INIT_PASSWORD@@" != 1 ]]; then
      echo "$(basename $HEADER): wiping (default) password slot(s)"
      $CRYPTENROLL_CMD --wipe-slot=password
    fi
  fi

  ##############################################################################
  echo "$(basename $HEADER): wiping empty slot(s)"
  $CRYPTENROLL_CMD --wipe-slot=empty

  if [ ! -z "$NEW_PASSWORD" ]; then
    echo "$(basename $HEADER): enrolling/updating password"
    # #FIXME - how to fake systemd-tty-ask-password-agent?
    # #FIXME $CRYPTENROLL_CMD --wipe-slot=password --password
  fi

  if [[ "@@MENDER/LUKS_CRYPTENROLL_TPM2@@" != 1 ]]; then
    echo "$(basename $HEADER): wiping tpm2 slot(s)"
    $CRYPTENROLL_CMD --wipe-slot=tpm2
  elif ! systemctl --quiet is-failed "*" || [ -z "${PCRS}" ]; then
    echo "$(basename $HEADER): enrolling tpm2 key sealed to PCRs: $PCRS"
    $CRYPTENROLL_CMD                            \
      --wipe-slot=tpm2                          \
      --tpm2-device=@@MENDER/LUKS_TPM2_DEVICE@@ \
      --tpm2-pcrs="$PCRS"
  else
    echo "$(basename $HEADER): system may be unstable, skipping sealing TPM to PCRs: $PCRS"
  fi

  if [[ "$WIPE_PASSWORD_SLOTS" == true ]]; then
    echo "$(basename $HEADER): wiping password slot(s)"
    $CRYPTENROLL_CMD --wipe-slot=password
  fi

  if [[ "$DUMP_SLOT_INFO" == true ]]; then
    echo "$(basename $HEADER): listing slot(s)"
    $CRYPTENROLL_CMD
  fi
done

exit
