#!/bin/sh

echo "will check status in @@MENDER/LUKS_SEAL_DELAY_SECS@@ seconds"

sleep @@MENDER/LUKS_SEAL_DELAY_SECS@@

rc=0

if systemctl --quiet is-system-running; then
  echo "sealing TPM PCRS to max: @@MENDER/LUKS_TPM_PCR_SET_MAX@@"
  mender-luks-tpm2-util.sh --write --pcrs max
  rc=$?
else
  echo "System may be unstable, not sealing TPM PCRs for fear of bricking system"
fi

exit $rc
