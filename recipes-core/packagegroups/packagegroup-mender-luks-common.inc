inherit packagegroup

RDEPENDS:${PN} += "     \
  ${MLPREFIX}cryptsetup \
"

RDEPENDS:${PN} += "${@bb.utils.contains("DISTRO_FEATURES", "tpm2",                "packagegroup-tpm2", "", d)}"
RDEPENDS:${PN} += "${@bb.utils.contains("DISTRO_FEATURES", "tpm2", "${MLPREFIX}mender-luks-tpm2-util", "", d)}"
