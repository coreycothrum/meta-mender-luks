DESCRIPTION = "meta-mender-luks system packages"

require packagegroup-mender-luks-common.inc

RDEPENDS:${PN} += "                     \
  ${MLPREFIX}mender-luks-cryptsetup     \
  ${MLPREFIX}mender-luks-luks-util      \
  ${MLPREFIX}mender-luks-password-agent \
  ${MLPREFIX}mender-luks-state-scripts  \
"

RDEPENDS:${PN} += "${@bb.utils.contains("MENDER/LUKS_BYPASS_REENCRYPT" , "1", "", "${MLPREFIX}mender-luks-reencrypt-on-default-password", d)}"
RDEPENDS:${PN} += "${@bb.utils.contains("MENDER/LUKS_BYPASS_RANDOM_KEY", "1", "", "${MLPREFIX}mender-luks-deny-default-password", d)}"
RDEPENDS:${PN} += "${@bb.utils.contains("DISTRO_FEATURES"              , "tpm2" , "${MLPREFIX}mender-luks-state-scripts-tpm", "", d)}"
