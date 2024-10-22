DESCRIPTION = "meta-mender-luks system packages"

require packagegroup-mender-luks-common.inc

RDEPENDS:${PN} += "          \
  mender-luks-cryptsetup     \
  mender-luks-password-agent \
  mender-luks-state-scripts  \
"
