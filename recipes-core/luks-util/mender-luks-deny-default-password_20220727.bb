SUMMARY          = "Change passphrase to random if set to default on boot"
DESCRIPTION      = "Change passphrase to random if set to default on boot"
LICENSE          = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

################################################################################

inherit systemd
inherit bitbake-variable-substitution

SYSTEMD_AUTO_ENABLE    = "enable"
SYSTEMD_SERVICE:${PN} += "mender-luks-deny-default-password.service"

SRC_URI                = "                                                                     \
                           file://mender-luks-deny-default-password.service                    \
                         "
FILES:${PN}            = "                                                                     \
                           ${systemd_unitdir}/system/mender-luks-deny-default-password.service \
                         "
RDEPENDS:${PN}         = "mender-luks-luks-util"

do_install () {
    install -d                                                           ${D}${systemd_unitdir}/system
    install -m 0644 ${WORKDIR}/mender-luks-deny-default-password.service ${D}${systemd_unitdir}/system
}
