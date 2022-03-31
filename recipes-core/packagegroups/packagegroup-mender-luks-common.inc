inherit packagegroup

RDEPENDS_${PN} += " \
  cryptsetup        \
  libgcc            \
"

RDEPENDS_${PN} += "${@bb.utils.contains("DISTRO_FEATURES", "tpm2", "packagegroup-tpm2"    , "", d)}"
RDEPENDS_${PN} += "${@bb.utils.contains("DISTRO_FEATURES", "tpm2", "mender-luks-tpm2-util", "", d)}"
