SUMMARY          = "mender-luks crypt/LUKS partition util(s)"
DESCRIPTION      = "mender-luks crypt/LUKS partition util(s)"
LICENSE          = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"
BBCLASSEXTEND    = "native nativesdk"

inherit bitbake-variable-substitution

################################################################################
SRC_URI = "                                             \
  file://mender-luks-cryptsetup-functions.sh            \
  file://mender-luks-cryptsetup-reencrypt-image-file.sh \
"

FILES:${PN} = "                                  \
  ${sbindir}/mender-luks-cryptsetup-functions.sh \
"

FILES:${PN}:class-native = "                                \
  ${sbindir}/mender-luks-cryptsetup-reencrypt-image-file.sh \
"

RDEPENDS:${PN} = "       \
  bash                   \
  coreutils              \
  cryptsetup             \
  mender-luks-cryptsetup \
  time                   \
  util-linux             \
"

RDEPENDS:${PN}:append:class-native = " \
  bmap-tools                           \
"

do_install() {
  install -d -m 755                                                ${D}${sbindir}
  install    -m 755 ${WORKDIR}/mender-luks-cryptsetup-functions.sh ${D}${sbindir}/
}

do_install:append:class-native() {
  install -d -m 755                                                           ${D}${sbindir}
  install    -m 755 ${WORKDIR}/mender-luks-cryptsetup-reencrypt-image-file.sh ${D}${sbindir}/
}
