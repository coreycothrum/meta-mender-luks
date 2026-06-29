IMAGE_INSTALL:append                     = " packagegroup-mender-luks"
INHERIT                                 += "mender-luks-setup"
PREFERRED_RPROVIDER_libdevmapper-native ?= "libdevmapper-native"

DISTRO_FEATURES:append     = " luks systemd pam"
DISTRO_FEATURES_OPTED_OUT += "sysvinit"

INITRAMFS_IMAGE                          = "mender-luks-initramfs"
INITRAMFS_LINK_NAME                      = "mender-luks-initramfs"
INITRAMFS_IMAGE_BUNDLE                   = "1"

################################################################################
LIVE_ROOTFS_TYPE     = ""
ROOTFS               = ""
IMAGE_FSTYPES:remove = " \
  biosimg.bz2 \
  gptimg.bz2  \
  sdimg.bz2   \
  uefiimg.bz2 \
  hddimg      \
  wic         \
  wic.zst     \
"
