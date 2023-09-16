#!/bin/bash

# © 2022 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

set -e

env_check() {
    if [ -z "$1" ]; then
        echo -e "\n$1 is not set"
        exit 1
    fi
}

checkenv_dir() {
    DIR=`printenv $1`
    if [[ ! -d "$DIR" ]]; then
        echo -e "Directory Doesn't Exists : $DIR"
        exit 1
    fi
}

ADDITIONAL_KERNEL_CONFIGS=" "

env_check BASE_DIR && checkenv_dir BASE_DIR

echo -e "\nLINUX_DIR : ${LINUX_DIR}"

mkdir -p ${LINUX_DIR}/build
cd ${LINUX_DIR}/src/linux

if [[ -f "./arch/arm64/configs/gunyah.config" ]]; then
	echo -e "Found Gunyah config, enabling virt and gunyah kernel config"
	ADDITIONAL_KERNEL_CONFIGS+=" virt.config gunyah.config"
fi

CPU_CNT=$(grep -c ^processor /proc/cpuinfo)

echo "Building Linux"

make ARCH=arm64 O=${LINUX_DIR}/build CROSS_COMPILE=aarch64-linux-gnu- defconfig ${ADDITIONAL_KERNEL_CONFIGS}

make ARCH=arm64 O=${LINUX_DIR}/build CROSS_COMPILE=aarch64-linux-gnu- -j${CPU_CNT}

if [[ ! -z "${QEMU_IMGS_DIR}" ]]; then
    cp ${LINUX_DIR}/build/arch/arm64/boot/Image ${QEMU_IMGS_DIR}
    echo "Copied Linux kernel Image to ${QEMU_IMGS_DIR}"
fi
