DESCRIPTION = "meta-mender-luks system packages"

require packagegroup-mender-luks-common.inc

RDEPENDS_${PN} += "          \
  mender-luks-cryptsetup     \
  mender-luks-luks-util      \
  mender-luks-password-agent \
  mender-luks-state-scripts  \
"

RDEPENDS_${PN} += "${@bb.utils.contains("MENDER/LUKS_BYPASS_RANDOM_KEY", "1", "", "mender-luks-blacklist-default-password", d)}"

RDEPENDS_${PN} += "${@bb.utils.contains("DISTRO_FEATURES", "tpm2", "mender-luks-state-scripts-tpm", "", d)}"
