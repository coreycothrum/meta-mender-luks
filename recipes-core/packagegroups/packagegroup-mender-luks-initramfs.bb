DESCRIPTION = "meta-mender-luks initramfs packages"

require packagegroup-mender-luks-common.inc

RDEPENDS_${PN} += "       \
  base-passwd             \
  busybox                 \
  mender-luks-init-script \
"
