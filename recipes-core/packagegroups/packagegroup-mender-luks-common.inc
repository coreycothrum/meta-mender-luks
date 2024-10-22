inherit packagegroup

RDEPENDS:${PN} += " \
  cryptsetup        \
"

RDEPENDS:${PN} += "${@bb.utils.contains("DISTRO_FEATURES", "tpm2", "mender-luks-legacy-tpm2-util", "", d)}"
