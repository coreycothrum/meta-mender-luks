SUMMARY          = "mender-luks state script(s)"
DESCRIPTION      = "mender-luks state script(s)"
LICENSE          = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

################################################################################
RDEPENDS_${PN} = "                    \
  coreutils                           \
  util-linux                          \
"
SRC_URI = "                           \
  file://cleanup.sh                   \
  file://mount-rootfs-by-dm-mapper.sh \
  file://noop.sh                      \
"

inherit bitbake-variable-substitution-helpers
inherit mender-state-scripts

do_compile() {
  cp ${WORKDIR}/noop.sh                      ${MENDER_STATE_SCRIPTS_DIR}/Download_Leave_00_mender-luks-noop.sh
  cp ${WORKDIR}/mount-rootfs-by-dm-mapper.sh ${MENDER_STATE_SCRIPTS_DIR}/ArtifactInstall_Enter_00_mender-luks-mount-rootfs-by-dm-mapper.sh
  cp ${WORKDIR}/cleanup.sh                   ${MENDER_STATE_SCRIPTS_DIR}/ArtifactInstall_Leave_05_mender-luks-cleanup.sh
  cp ${WORKDIR}/cleanup.sh                   ${MENDER_STATE_SCRIPTS_DIR}/ArtifactInstall_Error_05_mender-luks-cleanup.sh

  ${@bitbake_variables_search_and_sub(      "${MENDER_STATE_SCRIPTS_DIR}/", r"${BITBAKE_VAR_SUB_DELIM}", d)}
}

do_compile[nostamp] = "1"
