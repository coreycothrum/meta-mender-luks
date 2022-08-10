SUMMARY          = "mender-luks TPM state script(s)"
DESCRIPTION      = "mender-luks TPM state script(s)"
LICENSE          = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

################################################################################
RDEPENDS:${PN} = "                \
  coreutils                       \
  mender-luks-tpm2-util           \
  util-linux                      \
"
SRC_URI = "                               \
  file://abort-if-tpm-seal-in-progress.sh \
  file://cleanup.sh                       \
  file://noop.sh                          \
  file://unlock-tpm-for-reboot.sh         \
"

inherit bitbake-variable-substitution-helpers
inherit mender-state-scripts

do_compile() {
  cp ${WORKDIR}/abort-if-tpm-seal-in-progress.sh ${MENDER_STATE_SCRIPTS_DIR}/Download_Enter_00_mender-luks-abort-if-tpm-seal-in-progress.sh
  cp ${WORKDIR}/noop.sh                          ${MENDER_STATE_SCRIPTS_DIR}/Download_Leave_00_mender-luks-tpm-noop.sh
  cp ${WORKDIR}/unlock-tpm-for-reboot.sh         ${MENDER_STATE_SCRIPTS_DIR}/ArtifactInstall_Leave_20_mender-luks-tpm-unlock-for-reboot.sh
  cp ${WORKDIR}/unlock-tpm-for-reboot.sh         ${MENDER_STATE_SCRIPTS_DIR}/ArtifactInstall_Error_20_mender-luks-tpm-unlock-for-reboot.sh
  cp ${WORKDIR}/cleanup.sh                       ${MENDER_STATE_SCRIPTS_DIR}/ArtifactInstall_Leave_05_mender-luks-tpm-cleanup.sh
  cp ${WORKDIR}/cleanup.sh                       ${MENDER_STATE_SCRIPTS_DIR}/ArtifactInstall_Error_05_mender-luks-tpm-cleanup.sh

  ${@bitbake_variables_search_and_sub(          "${MENDER_STATE_SCRIPTS_DIR}/", r"${BITBAKE_VAR_SUB_DELIM}", d)}
}

do_compile[nostamp] = "1"
