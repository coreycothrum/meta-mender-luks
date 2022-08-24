#!/bin/sh

rc=0

if ! systemctl --quiet is-failed "*"; then
  echo "sealing TPM PCRS to max: @@MENDER/LUKS_TPM_PCR_SET_MAX@@"
  mender-luks-tpm2-util.sh --write --pcrs max
  rc=$?
else
  echo "System may be unstable, not sealing TPM PCRs for fear of bricking system"
  rc=1
fi

exit $rc
