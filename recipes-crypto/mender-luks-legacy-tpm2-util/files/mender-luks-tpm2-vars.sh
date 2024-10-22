#!/usr/bin/bash
################################################################################
export TPM2TOOLS_TCTI_NAME="device"
export TPM2TOOLS_DEVICE_FILE="/dev/tpmrm0"
export TPM2TOOLS_TCTI="${TPM2TOOLS_TCTI_NAME}:${TPM2TOOLS_DEVICE_FILE}"

export TPM_PCRS_SEAL="0,1,2,3,4,5"
export TPM_PCRS_UNSEAL="0"

export TPM_KEY_INDEX="0x81010001"
export TPM_KEY_SIZE_MAX="128"
export TPM_HIERARCHY="o"
export TPM_ATTRIBUTES="noda|adminwithpolicy|fixedparent|fixedtpm"
export TPM_KEY_ALG="rsa"
export TPM_PCR_ALG="sha256"
export TPM_HASH_ALG="sha256"
