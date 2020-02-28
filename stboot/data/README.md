## Table of Content
Directory | Description
------------ | -------------
[`/`](../../README.md#scripts) | entry point
[`configs/`](../../configs/README.md#configs) | configuration of operating systems
[`deploy/`](../../deploy/README.md#deploy) | scripts and files to build firmware binaries
[`deploy/coreboot-rom/`](../../deploy/coreboot-rom/README.md#deploy-coreboot-rom) | (work in progress)
[`deploy/mixed-firmware/`](../../deploy/mixed-firmware/README.md#deploy-mixed-firmware) | disk image solution
[`keys/`](../../keys/README.md#keys) | example certificates and signing keys
[`operating-system/`](../../operating-system/README.md#operating-system) | folders including scripts ans files to build reprodu>
[`operating-system/debian/`](../../operating-system/debian/README.md#operating-system-debian) | reproducible debian buster
[`operating-system/debian/docker/`](../../operating-system/debian/docker/README.md#operating-system-debian-docker) | docker environment
[`stboot/`](../README.md#stboot) | scripts and files to build stboot bootloader from source
[`stboot/include/`](../include/README.md#stboot-include) | fieles to be includes into the bootloader's initramfs
[`stboot/data/`](README.md#stboot-data) | fieles to be placed on a data partition of the host
[`stconfig/`](../../stconfig/README.md#stconfig) | scripts and files to build the bootloader's configuration tool

## Stboot Data
Files in this foder are ment to be places at a data partition at the host machine. This partition will be mounted by the bootloader.

### Scripts
#### `create_example_data.sh`
This script is invoked by 'run.sh'. It creates the files listed below with example data.

### Configuration Files
#### `network.json` (will be generated)
See https://www.system-transparency.org/usage/network.json

#### `provisioning-servers.json` (will be generated)
See https://www.system-transparency.org/usage/provisioning-servers.json

#### `https-root-certificates.pem` (will be generated)
See https://www.system-transparency.org/usage/https-root-certificates.pem

#### `ntp-servers.json` (will be generated)
See https://www.system-transparency.org/usage/ntp-servers.json