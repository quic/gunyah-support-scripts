#!/bin/bash

# © 2022 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

set -e

if [[ -z $KERNEL_IMAGE_DIR ]]; then
    KERNEL_IMAGE_DIR="./imgs"
fi

if [[ -z $INITRD_IMAGE_DIR ]]; then
    INITRD_IMAGE_DIR="./imgs"
fi

if [[ -z $HYP_IMAGE_DIR ]]; then
    HYP_IMAGE_DIR="./imgs"
fi

VIRTIO_BLK_DEVMAP=" "
PLATFORM_DDR_SIZE=2G
CPU_TYPE=max
#CPU_TYPE=cortex-a72

if [[ ! -z ${VIRTIO_DEVICE_FILE} ]]; then
    VIRTIO_BLK_DEVMAP=" -drive file=${VIRTIO_DEVICE_FILE},if=none,id=vd0,cache=writeback,format=raw -device virtio-blk,drive=vd0 "
fi

echo -e "Starting qemu-system-aarch64... (It may take a minute to see console output logs)\n\n"

./bin/qemu-system-aarch64 -machine virt,virtualization=on,gic-version=3,highmem=off \
	-cpu max -m size=$PLATFORM_DDR_SIZE -smp cpus=8  -nographic \
	-kernel ${KERNEL_IMAGE_DIR}/Image \
	-initrd ${INITRD_IMAGE_DIR}/initrd.img \
	${VIRTIO_BLK_DEVMAP} \
	-append "rw root=/dev/ram rdinit=/sbin/init earlyprintk=serial,ttyAMA0 console=ttyAMA0 nokaslr"
