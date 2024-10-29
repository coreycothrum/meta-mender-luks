DESCRIPTION = "mender-luks system package(s)"

require packagegroup-mender-luks-common.inc

RDEPENDS:${PN} += "          \
  mender-luks-password-agent \
  mender-luks-state-scripts  \
"
