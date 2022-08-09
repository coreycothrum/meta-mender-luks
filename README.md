# meta-mender-luks
LUKS encrypted rootfs and ``/data`` partitions for [meta-mender](https://github.com/mendersoftware/meta-mender). TPM2 integration for unattended boot.

Requires [meta-mender-kernel](https://github.com/coreycothrum/meta-mender-kernel) for separate A/B kernel partitions.

## Overview
* The ``/boot`` and [A/B kernel partitions](https://github.com/coreycothrum/meta-mender-kernel) are left unencrypted.
* The rootfs and ``/data`` partitions are encrypted with detached LUKS headers. The detached headers are stored on the ``/boot`` partition.
* The LUKS passphrase is stored in plain text on the (encrypted) ``/data`` partition.
* An ``ArtifactInstall`` state-script mounts the rootfs LUKS partition for ``mender-client`` access during an update.
* Optional [TPM2 integration](#tpm2-integration) for unattended boot.

### #FIXME - flesh this out more, bootflow, etc
\#FIXME - coming soon

### TPM2 Integration
Requires [meta-secure-core](https://github.com/jiazhang0/meta-secure-core). See [this kas file](kas/kas.tpm2.yml) for more setup details.

For unattended boot, the LUKS passphrase is loaded/sealed on the TPM2 device. This should be transparent to the user.
* ``mender-luks-password-agent`` reads key and provides to cryptsetup at boot
* ``mender-luks-tpm-key-watcher.service`` updates TPM2 when/if the LUKS key changes (on the filesystem)
* ``mender-luks-tpm-seal-on-boot.service`` reseals to ``MENDER/LUKS_TPM_PCR_SET_MAX`` if no systemd services have failed after ``MENDER/LUKS_SEAL_DELAY_SECS`` (i.e. a successful boot).
  Additional systemd dependencies can by added with ```MENDER/LUKS_SEAL_SYSTEMD_AFTER```.
* ``mender-luks-state-scripts-tpm`` reseals to ``MENDER/LUKS_TPM_PCR_SET_MIN`` after a mender artifact is written

## Utilities and Services
### luks-util
\#FIXME - coming soon

### tpm2-util
\#FIXME - coming soon

## Dependencies
This layer depends on:

    URI: git://git.openembedded.org/bitbake

    URI: git://git.openembedded.org/openembedded-core
    layers: meta
    branch: master

    URI: https://github.com/mendersoftware/meta-mender.git
    layers: meta-mender-core
    branch: master

    URI: https://github.com/coreycothrum/meta-mender-kernel.git
    layers: meta-mender-kernel
    branch: master

    URI: https://github.com/coreycothrum/meta-bitbake-variable-substitution.git
    layers: meta-bitbake-variable-substitution
    branch: master

## Installation
### Add Layer to Build
In order to use this layer, the build system must be aware of it.

Assuming this layer exists at the top-level of the yocto build tree; add the location of this layer to ``bblayers.conf``, along with any additional layers needed:

    BBLAYERS ?= "                                       \
      /path/to/yocto/meta                               \
      /path/to/yocto/meta-poky                          \
      /path/to/yocto/meta-yocto-bsp                     \
      /path/to/yocto/meta-mender/meta-mender-core       \
      /path/to/yocto/meta-bitbake-variable-substitution \
      /path/to/yocto/meta-mender-kernel                 \
      /path/to/yocto/meta-mender-luks                   \
      "

Alternatively, run bitbake-layers to add:

    $ bitbake-layers add-layer /path/to/yocto/meta-mender-luks

### Configure Layer
The following definitions should be added to ``local.conf`` or ``custom_machine.conf``

    require conf/include/mender-luks.inc

    MENDER/LUKS_PASSWORD             = "n3w_p@ssw0rd"

    # 0 = @ system boot: randomize LUKS password if weak or still set to default value
    # 1 = @ system boot: do not check LUKS password
    # MENDER/LUKS_BYPASS_RANDOM_KEY  = "1"

    # PCRs levels to seal TPM2
    # MENDER/LUKS_TPM_PCR_SET_NONE   = "0"
    # MENDER/LUKS_TPM_PCR_SET_MIN    = "0,1"
    # MENDER/LUKS_TPM_PCR_SET_MAX    = "0,1,2,3,4,5"

#### kas
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

Additional files in [kas/](kas/) have been provided to selectively turn on some features, such as [TPM2 integration](#tpm2-integration).

## Building
A [standalone reference](kas/reference_builds/kas.min.x86-64.yml) build kas file has been provided.

### Docker
All testing has been done with the `Dockerfile` located in [this repo](https://github.com/coreycothrum/yocto-builder-docker).

### Example/Reference Build
Commands executed from [docker image](https://github.com/coreycothrum/meta-mender-luks#docker):

    # clone repo
    cd $YOCTO_WORKDIR && git clone https://github.com/coreycothrum/meta-mender-luks.git

    # build TARGET image
    cd $YOCTO_WORKDIR && kas build $YOCTO_WORKDIR/meta-mender-luks/kas/reference_builds/kas.min.x86-64.yml

    # build QEMU image
    cd $YOCTO_WORKDIR && kas build $YOCTO_WORKDIR/meta-mender-luks/kas/reference_builds/kas.min.x86-64.yml:$YOCTO_WORKDIR/meta-mender-luks/kas/reference_builds/kas.qemu.yml

### Encrypting
Encryption is not an automated part of the build process. [This native script](recipes-core/mender-luks-encrypt-image/files/mender-luks-encrypt-image.sh) is provided as an optional post-build action.

This is only needed when provisioning a new device from the full disk image. The **mender artifacts work as-is** w/o this encryption step.

To execute the encryption script:

    bitbake       mender-luks-encrypt-image-native -caddto_recipe_sysroot       && \
    oe-run-native mender-luks-encrypt-image-native mender-luks-encrypt-image.sh <path_to_deploy_image>

This will take awhile. If it fails, it *may* not cleanup gracefully. Check `/dev/mapper` and `/dev/loop*` and cleanup as needed
(hint(s): `sudo dmsetup remove --force <NAME>` and `sudo losetup && sudo losetup -D`).

## Use Notes
* The mender update artifact (\*.mender) is **UNENCRYPTED**.
* ``MENDER_BOOT_PART_SIZE_MB`` needs to have capacity for detached LUKS headers.
* Enabling ``efi-secure-boot`` is recommended, especially when using unattended boot (requires [meta-secure-core](https://github.com/jiazhang0/meta-secure-core)).

## Contributing
Please submit any patches against this layer via pull request.

Commits must be signed off.

Use [conventional commits](https://www.conventionalcommits.org/).
