SUMMARY          = "NATIVE post build tool to encrypt build image"
DESCRIPTION      = "NATIVE post build tool to encrypt build image"
LICENSE          = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

################################################################################
SRC_URI        = "                                         \
                   file://mender-luks-encrypt-image.sh     \
                 "
FILES:${PN}    = "                                         \
                   ${sbindir}/mender-luks-encrypt-image.sh \
                 "

# why do I need to specify *-native here when this is already a native package?
RDEPENDS:${PN} = "                     \
                   bash                \
                   bash-native         \
                   bmaptool            \
                   bmaptool-native     \
                   coreutils           \
                   coreutils-native    \
                   cryptsetup          \
                   cryptsetup-native   \
                   libdevmapper        \
                   libdevmapper-native \
                   util-linux          \
                   util-linux-native   \
                 "

inherit bitbake-variable-substitution

do_install () {
    install -d -m 755                                         ${D}${sbindir}
    install    -m 755 ${WORKDIR}/mender-luks-encrypt-image.sh ${D}${sbindir}/
}
