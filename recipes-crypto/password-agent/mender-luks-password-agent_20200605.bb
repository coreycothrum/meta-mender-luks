SUMMARY           = "mender-luks systemd password agent"
DESCRIPTION       = "mender-luks systemd password agent"
LICENSE           = "MIT"
LIC_FILES_CHKSUM  = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI          += "                                           \
                      file://mender-luks-password-agent.cpp     \
                      file://mender-luks-password-agent.path    \
                      file://mender-luks-password-agent.service \
                    "
FILES:${PN}       = "                                                              \
                      ${sbindir}/mender-luks-password-agent                        \
                      ${systemd_unitdir}/system/mender-luks-password-agent.path    \ 
                      ${systemd_unitdir}/system/mender-luks-password-agent.service \ 
                    "
DEPENDS          += "         \
                      libinih \
                    "
RDEPENDS:${PN}   += "         \
                      libinih \
                    "

inherit bitbake-variable-substitution
inherit systemd

SYSTEMD_AUTO_ENABLE   = "enable"
SYSTEMD_SERVICE:${PN} = "mender-luks-password-agent.path"

LDFLAGS += "-L=/usr/lib -lINIReader -linih"

do_compile() {
  ${CXX} ${WORKDIR}/mender-luks-password-agent.cpp \
         ${CXXFLAGS} ${LDFLAGS}                    \
      -o ${WORKDIR}/mender-luks-password-agent
}

do_install() {
  install -d                                                    ${D}${sbindir}
  install -m 0700 ${WORKDIR}/mender-luks-password-agent         ${D}${sbindir}

  install -d                                                    ${D}${systemd_unitdir}/system
  install -m 0644 ${WORKDIR}/mender-luks-password-agent.path    ${D}${systemd_unitdir}/system
  install -m 0644 ${WORKDIR}/mender-luks-password-agent.service ${D}${systemd_unitdir}/system
}
