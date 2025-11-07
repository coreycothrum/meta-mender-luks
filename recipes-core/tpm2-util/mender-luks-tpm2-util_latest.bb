SUMMARY          = "TPM2 utility script(s)"
DESCRIPTION      = "TPM2 utility script(s)"
LICENSE          = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

################################################################################

inherit systemd
inherit bitbake-variable-substitution

SYSTEMD_AUTO_ENABLE    = "enable"
SYSTEMD_SERVICE:${PN} += "mender-luks-tpm-key-watcher.path"

SRC_URI = "                                  \
  file://mender-luks-tpm2-util.sh            \
  file://mender-luks-tpm-key-watcher.path    \
  file://mender-luks-tpm-key-watcher.service \
"
FILES:${PN} = "                                                 \
  ${sbindir}/mender-luks-tpm2-util.sh                           \
  ${systemd_unitdir}/system/mender-luks-tpm-key-watcher.path    \
  ${systemd_unitdir}/system/mender-luks-tpm-key-watcher.service \
"
RDEPENDS:${PN} = " \
  coreutils  \
  tpm2-tools \
"

do_install () {
  install -d -m 755                                                 ${D}${sbindir}
  install    -m 755  ${WORKDIR}/mender-luks-tpm2-util.sh            ${D}${sbindir}

  install -d                                                        ${D}${systemd_unitdir}/system
  install    -m 0644 ${WORKDIR}/mender-luks-tpm-key-watcher.path    ${D}${systemd_unitdir}/system
  install    -m 0644 ${WORKDIR}/mender-luks-tpm-key-watcher.service ${D}${systemd_unitdir}/system
}
