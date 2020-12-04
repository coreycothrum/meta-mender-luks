SUMMARY                    = "mender-luks initramfs"
LICENSE                    = "MIT"

export IMAGE_BASENAME      = "mender-luks-initramfs"
IMAGE_FEATURES             = ""
IMAGE_LINGUAS              = ""
IMAGE_FSTYPES              = "${INITRAMFS_FSTYPES}"

EXTRA_IMAGEDEPENDS         = ""
KERNELDEPMODDEPEND         = ""

INITRAMFS_MAXSIZE        ??= "256000"
IMAGE_ROOTFS_SIZE          = "8192"
IMAGE_ROOTFS_EXTRA_SPACE   = "0"

PACKAGE_INSTALL            = "${ROOTFS_BOOTSTRAP_INSTALL}"
PACKAGE_INSTALL           += "packagegroup-mender-luks-initramfs"

inherit core-image

require ${@bb.utils.contains('DISTRO_FEATURES', 'efi-secure-boot', 'conf/include/mender-kernel-initramfs-efi-secure-boot.inc', '', d)}
