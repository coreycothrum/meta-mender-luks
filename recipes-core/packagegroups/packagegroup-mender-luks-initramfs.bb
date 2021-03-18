DESCRIPTION = "meta-mender-luks initramfs packages"

require packagegroup-mender-luks-common.inc

RDEPENDS_${PN} += "       \
  base-passwd             \
  mender-luks-init-script \
"
