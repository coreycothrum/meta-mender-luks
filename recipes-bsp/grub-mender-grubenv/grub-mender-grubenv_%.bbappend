do_install:append() {
  oe_runmake -f ${S}/Makefile srcdir=${S} BOOT_DIR=${BOOT_DIR_LOCATION} EFI_DIR=${GRUB_CONF_BARE_LOCATION} DESTDIR=${D} install-legacy-tools
}
