#!/bin/bash

# © 2022 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

set -e

CPU_CNT=$(grep -c ^processor /proc/cpuinfo)

echo "Building Busybox"

RAMDISK_DIR="${LINUX_DIR}/busybox-1.33.0"
cd ${RAMDISK_DIR}
make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- defconfig
#make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- menuconfig
sed -i '/# CONFIG_STATIC is not set/c\CONFIG_STATIC=y' .config
ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- make -j${CPU_CNT}
ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- make install

cd _install
mkdir proc sys dev etc etc/init.d

cat <<EOF > etc/init.d/rcS
#!bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
EOF

chmod u+x etc/init.d/rcS
grep -v tty ../examples/inittab > ./etc/inittab
find . | cpio -o -H newc | gzip > ${RAMDISK_DIR}/initrd.img

if [[ ! -z "${QEMU_IMGS_DIR}" ]]; then
    cp ${RAMDISK_DIR}/initrd.img  ${QEMU_IMGS_DIR}
    echo "Copied Linux kernel Image to ${QEMU_IMGS_DIR}"
fi

echo -e "\nexport RAMDISK_FILE_PATH=${RAMDISK_DIR}/initrd.img\n" >> ~/.bashrc

