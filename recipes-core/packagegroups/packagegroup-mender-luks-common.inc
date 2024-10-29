inherit packagegroup

RDEPENDS:${PN} += "            \
  mender-luks-cryptenroll      \
  mender-luks-cryptsetup       \
  mender-luks-cryptsetup-utils \
  rng-tools                    \
"

RDEPENDS:${PN} += "${@bb.utils.contains("MENDER/LUKS_LEGACY_COMPAT", "1", "mender-luks-legacy-tpm2-util", "", d)}"
