#!/bin/bash

# © 2022 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

set -e

if [[ "$1" == "dbg" ]]; then
    ARGS=" -s -S "
    #ARGS=" -gdb tcp::1236 -S "
    echo "Running with debug stop"
fi

IMGS_FOLDER="./imgs"

if [[ -z "${HYP_IMG_FOLDER}" ]]; then
    HYP_IMG_FOLDER="${IMGS_FOLDER}"
fi

VIRTIO_BLK_DEVMAP=" "

#
# Qemu generates the dtb and copies to the base of DDR @ 0x40000000
#   Since the size of in memory dtb is 0x100000 (1MB) move other images
#   past that address to avoid overlapping
#
#  So current allocation:
#     DDR Base : 0x4000_0000  --  0xC000_0000 -1   (for 2GB config)
#
#     Free     : 0x4000_0000  --  0x4010_0000 -1   (1MB) Qemu places dt here for non elf kernels
#     Align    : 0x4010_0000  --  0x4020_0000 -1   (1MB) Align hypervisor
#
#     Hyp      : 0x4020_0000  --  0x4080_0000 -1  (6MB)
#
#     Initrd   : 0x4080_0000  --  0x40D0_0000 -1  (7MB)
#     Dtb      : 0x40F0_0000  --  0x4100_0000 -1  (1MB)
#     Kernel   : 0x4100_0000  --  0x4400_0000 -1
#
#     Linux primary VM will have 1GB of space till 0x8000_0000
#

INITRD_BASE=0x40800000
DT_BASE=0x40F00000
LINUX_BASE=0x41000000

HYP_BASE=0x40200000
HYP_SIZE=0x600000

PLATFORM_DDR_SIZE=2G
LINUX_VM_MEMORY_SIZE=1G
CPU_TYPE=max
#CPU_TYPE=cortex-a72

if [[ "$1" == "dtb" ]]; then

    if [[ ! -z "${VIRTIO_DEVICE_FILE}" ]]; then
	    CMD_LINE="root=/dev/vda"
    else
	    CMD_LINE="rw root=/dev/ram rdinit=/sbin/init earlyprintk=serial,ttyAMA0 console=ttyAMA0 "
    fi

    if [[ ! -f $IMGS_FOLDER/virt.dtb ]]; then
	./bin/qemu-system-aarch64 -machine virt,virtualization=on,gic-version=3,highmem=off \
	   -cpu $CPU_TYPE -m size=$LINUX_VM_MEMORY_SIZE -smp cpus=8  -nographic  \
	   -kernel $HYP_IMG_FOLDER/hypvm.elf \
	   -device loader,file=$IMGS_FOLDER/Image,addr=$LINUX_BASE \
	   -device loader,file=$IMGS_FOLDER/initrd.img,addr=$INITRD_BASE \
	   -append "$CMD_LINE " \
	   -machine dumpdtb=$IMGS_FOLDER/virt.dtb
    fi

    # Give Linux kernel only 1GB of memory
    echo "Generating dtb and exiting..."

    ./bin/qemu-system-aarch64 -machine virt,virtualization=on,gic-version=3,highmem=off \
       -cpu $CPU_TYPE -m size=$LINUX_VM_MEMORY_SIZE -smp cpus=8  -nographic  \
       -kernel $HYP_IMG_FOLDER/hypvm.elf \
       -device loader,file=$IMGS_FOLDER/Image,addr=$LINUX_BASE \
       -device loader,file=$IMGS_FOLDER/virt.dtb,addr=$DT_BASE \
       -device loader,file=$IMGS_FOLDER/initrd.img,addr=$INITRD_BASE \
       -append "$CMD_LINE " \
       -machine dumpdtb=$IMGS_FOLDER/virt_qemu.dtb

   #-append "rw root=/dev/ram rdinit=/sbin/init earlyprintk=serial,ttyAMA0 console=ttyAMA0 nokaslr " \

    export INITRD_SIZE=$(stat -Lc %s $IMGS_FOLDER/initrd.img)
    export INITRD_END=$(printf "0x%x" $((${INITRD_BASE} + ${INITRD_SIZE})))
    export HYP_MEM_BASE=$(printf "%x" $((${HYP_BASE})))
    export HYP_MEM_SIZE=$(printf "0x%x" $((${HYP_SIZE})))
    cat <<EOF > $IMGS_FOLDER/overlay.dts
    /dts-v1/;
    /{
	fragment@0{
	target-path = "/chosen";
	    __overlay__{
		linux,initrd-start = <${INITRD_BASE}>;
		linux,initrd-end = <${INITRD_END}>;
	    };
	};

    };
EOF

    dtc -@  -I dts -O dtb $IMGS_FOLDER/overlay.dts -o $IMGS_FOLDER/overlay.dtbo
    fdtoverlay -v -i $IMGS_FOLDER/virt_qemu.dtb -o $IMGS_FOLDER/virt.dtb $IMGS_FOLDER/overlay.dtbo
    dtc -I dtb -O dts -o $IMGS_FOLDER/virt.dts $IMGS_FOLDER/virt.dtb

    # Remove ITS node and msi-map which doesn't work well
    cat $IMGS_FOLDER/virt.dts | sed '/its@/,/};/d' | grep -v "msi-map " > $IMGS_FOLDER/virt-pp.dts  &&  mv $IMGS_FOLDER/virt-pp.dts $IMGS_FOLDER/virt.dts

    dtc -I dts -O dtb -o $IMGS_FOLDER/virt.dtb $IMGS_FOLDER/virt.dts

    echo "Generated dtb $IMGS_FOLDER/virt.dtb"

else

    if [[ ! -z "${VIRTIO_DEVICE_FILE}" ]]; then
        # Map the virt device
	VIRTIO_BLK_DEVMAP=" -drive file=${VIRTIO_DEVICE_FILE},if=none,id=vd0,cache=writeback,format=raw -device virtio-blk,drive=vd0 "
        # VIRTIO_BLK_DEVMAP=" -drive if=virtio,format=raw,file=${VIRTIO_DEVICE_FILE} -device virtio-scsi-pci,id=scsi0  "
    fi

    #  Update the image for every run, just in case if we built it as part of development process.
    #  Set the env variable in rc file to udpate
    if [[ ! -z  "${HYP_ROOT_PATH}" ]]; then
    	cp ${HYP_ROOT_PATH}/qemu/hypvm.elf ./imgs/
    fi

    ./bin/qemu-system-aarch64 -machine virt,virtualization=on,gic-version=3,highmem=off \
	-cpu max,sve128=on -m size=$PLATFORM_DDR_SIZE -smp cpus=8  -nographic \
	-accel tcg,thread=multi \
	-kernel $HYP_IMG_FOLDER/hypvm.elf \
	-device loader,file=$IMGS_FOLDER/virt.dtb,addr=$DT_BASE \
	-device loader,file=$IMGS_FOLDER/Image,addr=$LINUX_BASE \
	-device loader,file=$IMGS_FOLDER/initrd.img,addr=$INITRD_BASE \
	${VIRTIO_BLK_DEVMAP} \
	$ARGS

# 	-monitor telnet::45454,server,nowait \
#	-serial telnet:localhost:1235,server \

fi
