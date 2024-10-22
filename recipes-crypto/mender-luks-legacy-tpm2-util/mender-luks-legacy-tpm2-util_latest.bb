SUMMARY          = "mender-luks legacy tpm2 utility"
DESCRIPTION      = "mender-luks legacy tpm2 utility"
LICENSE          = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

################################################################################
inherit bitbake-variable-substitution

SRC_URI = "                       \
  file://mender-luks-tpm2-util.sh \
  file://mender-luks-tpm2-vars.sh \
"

FILES:${PN} = "                       \
  ${sbindir}/mender-luks-tpm2-util.sh \
  ${sbindir}/mender-luks-tpm2-vars.sh \
"

RDEPENDS:${PN} = "  \
  bash              \
  coreutils         \
  packagegroup-tpm2 \
  tpm2-tools        \
"

do_install () {
  install -d -m 755                                     ${D}${sbindir}
  install    -m 755 ${WORKDIR}/mender-luks-tpm2-util.sh ${D}${sbindir}
  install    -m 755 ${WORKDIR}/mender-luks-tpm2-vars.sh ${D}${sbindir}
}
