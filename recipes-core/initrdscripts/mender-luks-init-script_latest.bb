SUMMARY          = "mender-luks /init script"
LICENSE          = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://mender-luks-init.sh"

FILES:${PN} = " \
  /init         \
  /dev          \
"

RDEPENDS:${PN} = " \
  bash             \
  coreutils        \
  cryptsetup       \
  kmod             \
  util-linux       \
"

RECOMMENDS_${PN} = "    \
  kernel-module-tpm-crb \
  kernel-module-tpm-tis \
"

inherit bitbake-variable-substitution

do_install () {
  install -m 0755 ${WORKDIR}/mender-luks-init.sh ${D}/init
}
