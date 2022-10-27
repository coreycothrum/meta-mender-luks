SUMMARY                = "reencrypt LUKS master key(s) if passphrase set to default on boot"
DESCRIPTION            = "reencrypt LUKS master key(s) if passphrase set to default on boot"
LICENSE                = "MIT"
LIC_FILES_CHKSUM       = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI                = "file://mender-luks-reencrypt-on-default.conf"
FILES:${PN}            = "${systemd_unitdir}/system/mender-luks-deny-default-password.service.d/*"
RDEPENDS:${PN}         = "mender-luks-deny-default-password"

inherit bitbake-variable-substitution

do_install () {
    install -d                                                       ${D}${systemd_unitdir}/system/mender-luks-deny-default-password.service.d
    install -m 0644 ${WORKDIR}/mender-luks-reencrypt-on-default.conf ${D}${systemd_unitdir}/system/mender-luks-deny-default-password.service.d
}
