DESCRIPTION = "meta-mender-luks initramfs packages"

require packagegroup-mender-luks-common.inc

RDEPENDS:${PN} += "                  \
  ${MLPREFIX}base-passwd             \
  ${MLPREFIX}mender-luks-init-script \
"
