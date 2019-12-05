#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

if [ -z "$var" ]
then
      echo "usage: umount.sh path/to/loopdev"
fi

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

failed="\e[1;5;31mfailed\e[0m"

# Set magic variables for current file & dir
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
file="${dir}/$(basename "${BASH_SOURCE[0]}")"
base="$(basename ${file} .sh)"
root="$(cd "${dir}/../../" && pwd)"

dev=$1
mnt="/tmp/mnt_stimg"
img="${dir}/MBR_Syslinux_Linuxboot.img"
echo "[INFO]: unmount ${img}"
umount ${mnt} || { echo -e "umount $failed"; losetup -d ${dev}; exit 1; }
rm -r -f ${mnt} || { echo -e "cleanup tmpdir $failed"; losetup -d ${dev}; exit 1; } 
losetup -d ${dev} || { echo -e "losetup -d $failed"; exit 1; }
echo "[INFO]: loop device is free again"
