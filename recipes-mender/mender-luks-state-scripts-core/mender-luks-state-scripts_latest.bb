SUMMARY          = "mender-luks state script(s)"
DESCRIPTION      = "mender-luks state script(s)"
LICENSE          = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

################################################################################
RDEPENDS:${PN} = "                      \
  coreutils                             \
  util-linux                            \
"
SRC_URI = "                             \
  file://abort-if-update-in-progress.sh \
  file://cleanup.sh                     \
  file://mount-rootfs-by-dm-mapper.sh   \
"
S = "${UNPACKDIR}"

inherit bitbake-variable-substitution-helpers
inherit mender-state-scripts

do_compile() {
  cp ${S}/abort-if-update-in-progress.sh ${MENDER_STATE_SCRIPTS_DIR}/Download_Enter_00_mender-luks-abort-if-update-in-progress.sh
  cp ${S}/mount-rootfs-by-dm-mapper.sh   ${MENDER_STATE_SCRIPTS_DIR}/ArtifactInstall_Enter_00_mender-luks-mount-rootfs-by-dm-mapper.sh
  cp ${S}/cleanup.sh                     ${MENDER_STATE_SCRIPTS_DIR}/ArtifactInstall_Leave_05_mender-luks-cleanup.sh
  cp ${S}/cleanup.sh                     ${MENDER_STATE_SCRIPTS_DIR}/ArtifactInstall_Error_05_mender-luks-cleanup.sh

  ${@bitbake_variables_search_and_sub(  "${MENDER_STATE_SCRIPTS_DIR}/", r"${BITBAKE_VAR_SUB_DELIM}", d)}
}

ALLOW_EMPTY:${PN} = "1"
