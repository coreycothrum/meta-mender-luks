# meta-mender-luks
LUKS encrypted rootfs and ``/data`` partitions for [meta-mender](https://github.com/mendersoftware/meta-mender). TPM2 integration for unattended boot.

Requires [meta-mender-kernel](https://github.com/coreycothrum/meta-mender-kernel) for separate A/B kernel partitions.

## Overview
* The ``/boot`` and [A/B kernel partitions](https://github.com/coreycothrum/meta-mender-kernel) are left unencrypted.
* The rootfs and ``/data`` partitions are encrypted with detached LUKS headers. The detached headers are stored on the ``/boot`` partition.
* The LUKS passphrase is stored in plain text on the (encrypted) ``/data`` partition.
* An ``ArtifactInstall`` state-script mounts the rootfs LUKS partition for ``mender-client`` access during an update.
* Optional [TPM2 integration](#tpm2-integration) for unattended boot.

### TPM2 Integration
Requires [meta-secure-core](https://github.com/jiazhang0/meta-secure-core). See [this kas file](kas/kas.tpm2.yml) for more setup details.

For unattended boot, the LUKS passphrase is sealed/stored on the TPM2 device.
This key is read from the TPM2, and then written into the systemd credential framework, during the initramfs stage.
The key can then be accessed by cryptsetup to unlock the encrypted partitions.
All this should be transparent to the user.

Custom mender state scripts (``mender-luks-state-scripts-tpm``) will:
  * unlock/unseal to ``MENDER/LUKS_TPM_PCR_UPDATE_UNLOCK`` after a mender artifact is installed/written.
  * lock/seal to ``MENDER/LUKS_TPM_PCR_SET_MAX`` after a mender artifact is committed.

## Installation
* Add this layer to ``bblayers.conf``. Note this layer has dependencies:
   * ``meta-bitbake-variable-substitution``
   * ``meta-mender-kernel``
* ``local.conf`` should include: ``require conf/include/mender-luks.inc``, along with any [configuration variables](#configuration)

## Configuration
The following definitions should be added to ``local.conf`` or ``custom_machine.conf``

    require conf/include/mender-luks.inc

    MENDER/LUKS_PASSWORD                = "n3w_p@ssw0rd"

    # 0 = @ system boot: randomize LUKS password if weak or still set to default value
    # 1 = @ system boot: do not check LUKS password
    # MENDER/LUKS_BYPASS_RANDOM_KEY     = "1"

    # 0 = @ system boot: reencrypt LUKS master key(s) if password is still set to default value
    # 1 = @ system boot: do no reencrypt LUKS partitions
    # MENDER/LUKS_BYPASS_REENCRYPT      = "1"

    # PCRs levels to seal TPM2
    # unlock options: none | min | max | N,N,N
    # MENDER/LUKS_TPM_PCR_SET_NONE      = "0"
    # MENDER/LUKS_TPM_PCR_SET_MIN       = "0,1"
    # MENDER/LUKS_TPM_PCR_SET_MAX       = "0,1,2,3,4,5"
    # MENDER/LUKS_TPM_PCR_UPDATE_UNLOCK = "min"

### kas
Alternatively, a [kas](https://github.com/siemens/kas) file has been provided to help with setup/config. [Include](https://kas.readthedocs.io/en/latest/userguide.html#including-configuration-files-from-other-repos) `kas/kas.yml` from this layer in the top level kas file. E.g.:

    header:
      version : 1
      includes:
        - repo: meta-mender-luks
          file: kas/kas.yml

    local_conf_header:
      01_meta-mender-luks: |
        # define here, or in a custom layer
        MENDER/LUKS_PASSWORD          = "n3w_p@ssw0rd"
        MENDER/LUKS_BYPASS_RANDOM_KEY = "1"
        MENDER/LUKS_BYPASS_REENCRYPT  = "1"

Additional files in [kas/](kas/) have been provided to selectively turn on some features, such as [TPM2 integration](#tpm2-integration).

## Image Encryption
Image encryption is not an automated part of the build process. It can be done with either a post-build script ~~, or on system during 1st boot~~.

The **mender artifact(s) work as-is** w/o this encryption step.
If all you need is the mender artifact(s), then no further action is required.
Image encryption is only significant when provisioning a new system.

### Post-Build Encryption Script
The initial run of this script will luksFormat the partitions. Subsequent runs will reencrypt partitions in-place.

To execute:

    bitbake mender-luks-cryptsetup-utils-native -caddto_recipe_sysroot \
    && PASSWORD="p1" oe-run-native mender-luks-cryptsetup-utils-native \
       mender-luks-cryptsetup-reencrypt-image-file.sh /path/to/IMAGE_FILE

This will/may take awhile. On failure, it *may* not cleanup gracefully. Check ``/dev/mapper`` and ``/dev/loop*`` and cleanup as needed:

    sudo dmsetup remove --force <NAME>
    sudo losetup && sudo losetup -D

## Use Notes
* The mender update artifact (\*.mender) remains **UNENCRYPTED**.
* ``MENDER_BOOT_PART_SIZE_MB`` needs to have capacity for detached LUKS headers.
* Enabling ``efi-secure-boot`` is recommended, especially when using unattended boot (requires [meta-secure-core](https://github.com/jiazhang0/meta-secure-core)).

## Release Schedule and Roadmap
This layer will remain compatible with the latest [YOCTO LTS](https://wiki.yoctoproject.org/wiki/Releases). This mirrors [meta-mender](https://github.com/mendersoftware/meta-mender).
