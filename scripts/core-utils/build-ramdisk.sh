#!/bin/bash

# © 2022 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

set -e

CPU_CNT=$(grep -c ^processor /proc/cpuinfo)

BUSYBOX_VER=busybox-1.33.0
BUSYBOX_FILE=${BUSYBOX_VER}.tar.bz2

echo "Building Busybox"

if [[ -z "${LINUX_DIR}" ]]; then
	echo "LINUX_DIR location not provided"
	return
fi

RAMDISK_DIR="${LINUX_DIR}/${BUSYBOX_VER}"

echo -e "\nClone linux sources to LINUX_DIR : ${LINUX_DIR}"

if [[ ! -d ${RAMDISK_DIR} ]]; then

    echo -e "\nDownloading Busybox:"
    cd ${LINUX_DIR}
    wget -c https://busybox.net/downloads/${BUSYBOX_FILE} || {
    	echo "Unable to Download busybox"
    	return
    }

    tar xf ${BUSYBOX_FILE} || {
    	echo "Unable to Uncompress busybox"
    	return
    }
fi

if [[ ! -f ${RAMDISK_DIR}/initrd.img ]]; then
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
    cp ${RAMDISK_DIR}/initrd.img  "${LINUX_DIR}/"
fi

if [[ ! -z "${QEMU_IMGS_DIR}" ]] && [[ ! -f ${QEMU_IMGS_DIR}/initrd.img ]]; then
    cp ${RAMDISK_DIR}/initrd.img  "${QEMU_IMGS_DIR}/"
    echo "Copied Linux kernel Image to ${QEMU_IMGS_DIR}"
fi
