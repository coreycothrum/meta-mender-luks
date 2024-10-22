SUMMARY          = "mender-luks mender state script(s)"
DESCRIPTION      = "mender-luks mender state script(s)"
LICENSE          = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit bitbake-variable-substitution-helpers
inherit mender-state-scripts

################################################################################
RDEPENDS:${PN} = "                    \
  coreutils                           \
  util-linux                          \
"

SRC_URI = "                           \
  file://cleanup.sh                   \
  file://mount-rootfs-by-dm-mapper.sh \
  file://noop.sh                      \
  file://tpm-seal.sh                  \
  file://tpm-unseal.sh                \
"

################################################################################
################################################################################
################################################################################
do_compile() {
  cp ${WORKDIR}/noop.sh                      ${MENDER_STATE_SCRIPTS_DIR}/Download_Leave_00_mender-luks-noop.sh
  cp ${WORKDIR}/mount-rootfs-by-dm-mapper.sh ${MENDER_STATE_SCRIPTS_DIR}/ArtifactInstall_Enter_00_mender-luks-mount-rootfs-by-dm-mapper.sh
  cp ${WORKDIR}/cleanup.sh                   ${MENDER_STATE_SCRIPTS_DIR}/ArtifactInstall_Leave_05_mender-luks-cleanup.sh
  cp ${WORKDIR}/cleanup.sh                   ${MENDER_STATE_SCRIPTS_DIR}/ArtifactInstall_Error_05_mender-luks-cleanup.sh

  ${@bb.utils.contains('DISTRO_FEATURES', 'tpm2', 'true', 'false', d)} && tpm2_scripts
}

################################################################################
tpm2_scripts() {
  cp ${WORKDIR}/tpm-unseal.sh ${MENDER_STATE_SCRIPTS_DIR}/ArtifactInstall_Leave_20_mender-luks-tpm-unseal.sh
  cp ${WORKDIR}/tpm-unseal.sh ${MENDER_STATE_SCRIPTS_DIR}/ArtifactInstall_Error_20_mender-luks-tpm-unseal.sh

  cp ${WORKDIR}/tpm-seal.sh   ${MENDER_STATE_SCRIPTS_DIR}/ArtifactCommit_Leave_20_mender-luks-tpm-seal.sh
  cp ${WORKDIR}/tpm-seal.sh   ${MENDER_STATE_SCRIPTS_DIR}/ArtifactRollbackReboot_Leave_20_mender-luks-tpm-seal.sh
}

################################################################################
do_compile:append() {
  ${@bitbake_variables_search_and_sub("${MENDER_STATE_SCRIPTS_DIR}/", r"${BITBAKE_VAR_SUB_DELIM}", d)}
}
