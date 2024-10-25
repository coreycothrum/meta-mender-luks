DESCRIPTION = "mender-luks initramfs package(s)"

require packagegroup-mender-luks-common.inc

RDEPENDS:${PN} += "       \
  base-passwd             \
  mender-luks-init-script \
"
