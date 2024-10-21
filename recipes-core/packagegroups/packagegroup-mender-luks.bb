DESCRIPTION = "meta-mender-luks system packages"

require packagegroup-mender-luks-common.inc

RDEPENDS:${PN} += "                     \
  ${MLPREFIX}mender-luks-cryptsetup     \
  ${MLPREFIX}mender-luks-password-agent \
  ${MLPREFIX}mender-luks-state-scripts  \
"

RDEPENDS:${PN} += "${@bb.utils.contains("DISTRO_FEATURES", "tpm2", "${MLPREFIX}mender-luks-state-scripts-tpm", "", d)}"
