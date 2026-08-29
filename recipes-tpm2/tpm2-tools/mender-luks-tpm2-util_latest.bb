SUMMARY          = "meta-mender-luks TPM2 utility script"
DESCRIPTION      = "meta-mender-luks TPM2 utility script"
LICENSE          = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

################################################################################
inherit systemd
inherit bitbake-variable-substitution

SYSTEMD_AUTO_ENABLE    = "enable"
SYSTEMD_SERVICE:${PN} += "mender-luks-tpm-key-watcher.path"

S = "${UNPACKDIR}"
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
RDEPENDS:${PN} = "  \
  coreutils         \
  packagegroup-tpm2 \
  util-linux        \
"

################################################################################
TPM2TOOLS_TCTI_NAME   = "device"
TPM2TOOLS_DEVICE_FILE = "/dev/tpmrm0"
TPM_KEY_INDEX         = "0x81010001"
TPM_KEY_SIZE_MAX      = "128"
TPM_HIERARCHY         = "o"
TPM_ATTRIBUTES        = "noda|adminwithpolicy|fixedparent|fixedtpm"
TPM_KEY_ALG           = "rsa"
TPM_PCR_ALG           = "sha256"
TPM_HASH_ALG          = "sha256"
TPM_PCR_SET_NONE      = "0"
TPM_PCR_SET_MIN       = "0"
TPM_PCR_SET_MAX       = "0"
TPM_PCR_UPDATE_UNLOCK = "min"

################################################################################
do_install () {
  install -d -m 755                                           ${D}${sbindir}
  install    -m 755  ${S}/mender-luks-tpm2-util.sh            ${D}${sbindir}

  install -d                                                  ${D}${systemd_unitdir}/system
  install    -m 0644 ${S}/mender-luks-tpm-key-watcher.path    ${D}${systemd_unitdir}/system
  install    -m 0644 ${S}/mender-luks-tpm-key-watcher.service ${D}${systemd_unitdir}/system
}
