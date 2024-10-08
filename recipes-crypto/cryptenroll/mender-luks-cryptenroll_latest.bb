SUMMARY          = "mender-luks: setup, enroll, and maintain LUKs keys"
DESCRIPTION      = "mender-luks: setup, enroll, and maintain LUKs keys"
LICENSE          = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

################################################################################
inherit systemd
inherit bitbake-variable-substitution

SYSTEMD_AUTO_ENABLE    = "enable"
SYSTEMD_SERVICE:${PN} += "mender-luks-cryptenroll.service"
SRC_URI                = "                                        \
                           file://mender-luks-cryptenroll.sh      \
                           file://mender-luks-cryptenroll.service \
                         "
FILES:${PN}            = "                                                           \
                           ${sbindir}/mender-luks-cryptenroll.sh                     \
                           ${systemd_unitdir}/system/mender-luks-cryptenroll.service \
                         "
RDEPENDS:${PN}         = "               \
                           coreutils     \
                           cracklib      \
                           cryptsetup    \
                           systemd-crypt \
                         "
do_install () {
  install -d -m 755                                          ${D}${sbindir}
  install    -m 755 ${WORKDIR}/mender-luks-cryptenroll.sh    ${D}${sbindir}

  install -d                                                 ${D}${systemd_unitdir}/system
  install -m 0644 ${WORKDIR}/mender-luks-cryptenroll.service ${D}${systemd_unitdir}/system
}
