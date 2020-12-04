IMAGE_INSTALL_append                += "packagegroup-mender-luks"
INHERIT                             += "mender-luks-setup"

INITRAMFS_IMAGE                      = "mender-luks-initramfs"
INITRAMFS_LINK_NAME                  = "mender-luks-initramfs"
INITRAMFS_IMAGE_BUNDLE               = "1"

################################################################################
LIVE_ROOTFS_TYPE                     = ""
ROOTFS                               = ""
IMAGE_FSTYPES_remove                += "${MENDER/LUKS_BLACKLISTED_IMAGE_TYPES}"

################################################################################
DISTRO_FEATURES_append              += "systemd pam"
DISTRO_FEATURES_BACKFILL_CONSIDERED += "sysvinit"
VIRTUAL-RUNTIME_login_manager        = "shadow-base"
VIRTUAL-RUNTIME_init_manager         = "systemd"
VIRTUAL-RUNTIME_initscripts          = "systemd-compat-units"
