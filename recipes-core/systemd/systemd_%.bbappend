PACKAGECONFIG:append = " cryptsetup"
PACKAGECONFIG:append = "${@bb.utils.contains("DISTRO_FEATURES", "tpm2", " tpm2", "", d)}"
