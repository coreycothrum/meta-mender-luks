SUMMARY          = "mender-luks TPM state script(s)"
DESCRIPTION      = "mender-luks TPM state script(s)"
LICENSE          = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

################################################################################
RDEPENDS:${PN} = "      \
  coreutils             \
  mender-luks-tpm2-util \
  util-linux            \
"
SRC_URI = "            \
  file://tpm-seal.sh   \
  file://tpm-unseal.sh \
"

inherit bitbake-variable-substitution-helpers
inherit mender-state-scripts

do_compile() {
  cp ${WORKDIR}/tpm-seal.sh   ${MENDER_STATE_SCRIPTS_DIR}/ArtifactCommit_Leave_90_mender-luks-tpm-seal.sh
  cp ${WORKDIR}/tpm-seal.sh   ${MENDER_STATE_SCRIPTS_DIR}/ArtifactRollbackReboot_Leave_90_mender-luks-tpm-seal.sh

  cp ${WORKDIR}/tpm-unseal.sh ${MENDER_STATE_SCRIPTS_DIR}/ArtifactInstall_Error_20_mender-luks-tpm-unseal.sh
  cp ${WORKDIR}/tpm-unseal.sh ${MENDER_STATE_SCRIPTS_DIR}/ArtifactInstall_Leave_20_mender-luks-tpm-unseal.sh
  cp ${WORKDIR}/tpm-unseal.sh ${MENDER_STATE_SCRIPTS_DIR}/ArtifactRollback_Leave_20_mender-luks-tpm-unseal.sh

  ${@bitbake_variables_search_and_sub("${MENDER_STATE_SCRIPTS_DIR}/", r"${BITBAKE_VAR_SUB_DELIM}", d)}
}

ALLOW_EMPTY:${PN} = "1"
