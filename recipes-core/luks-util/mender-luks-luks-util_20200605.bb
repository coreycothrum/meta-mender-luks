SUMMARY          = "LUKS setup and utility scripts"
DESCRIPTION      = "LUKS setup and utility scripts"
LICENSE          = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

################################################################################
SRC_URI          = "                                \
                     file://mender-luks-util.sh     \
                   "
FILES:${PN}      = "                                \
                     ${sbindir}/mender-luks-util.sh \
                   "
RDEPENDS:${PN}   = "            \
                     coreutils  \
                     cracklib   \
                     cryptsetup \
                     jq         \
                     openssl    \
                   "

inherit bitbake-variable-substitution

do_install () {
    install -d -m 755                                ${D}${sbindir}
    install    -m 755 ${WORKDIR}/mender-luks-util.sh ${D}${sbindir}/
}
