#!/bin/bash

# © 2023 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

set -e

# Build extfs image to mount to linux as virtio blk device disk

VALID_ARGS=$(getopt -o pf:o:s: --long folder:,outfile:,size:,parti -- "$@")

if [[ $# -le 2 ]]; then
	echo -e "Usage: $(basename $0) <args>\n args:"
    echo -e "\t -f|--folder  path : Input folder path"
    echo -e "\t -o|--outfile path : Path name of file to create"
    echo -e "\t -s|--size    xxx  : Image size to create. KMG can be used for units"
    echo -e "\t -p|--parti        : Create partition in the disk"
    exit 1;
fi

eval set -- "$VALID_ARGS"
while [ : ]; do
  case "$1" in
    -f | --folder)
	IN_FOLDER=$2
        #echo "Input folder: ${IN_FOLDER}"
        shift 2
        ;;
    -o | --outfile)
	OUT_FILE=$2
	#echo "Output file: ${OUT_FILE}"
        shift 2
        ;;
    -s | --size)
	DISK_SIZE=$2
	#echo "Disk size: ${DISK_SIZE}"
        shift 2
        ;;
    -p | --parti)
	DISK_PARTI="YES"
	#echo "Partition Disk"
        shift
        ;;
    --) shift; 
        break 
        ;;
  esac
done

if [[ ! -d ${IN_FOLDER} ]]; then
    echo "${IN_FOLDER} not found!"
    exit 1
fi

if [[ -f ${OUT_FILE} ]]; then
    echo "File ${OUT_FILE} already exists..!!"
    exit 2
fi

#dd if=/dev/zero of=extfs-disk.img bs=1k count=512k
qemu-img create -f raw ${OUT_FILE} ${DISK_SIZE}

mkdir -p ./tmp-ext-fs

if [[ -z ${DISK_PARTI} ]]; then

    # Disk image, NO partitioning
    echo "Creating Disk image without partition"

    mkfs.ext4 ${OUT_FILE}
    sudo mount  -o loop ${OUT_FILE} ./tmp-ext-fs

else
    # Disk image, with partitioning

    echo "Creating Partition on the Disk"

    (echo n; echo p; echo 1; echo "" ; echo "" ; echo p; echo w) | fdisk ${OUT_FILE}

    PARTI_OFFSET=`fdisk -l ${OUT_FILE} | grep "${OUT_FILE}1" | xargs | cut -d " " -f 2`
    mkfs.ext4 ${OUT_FILE} -E offset=$(( 512 * ${PARTI_OFFSET} ))

    sudo mount  -o loop,offset=$(( 512 * $PARTI_OFFSET )) ${OUT_FILE} ./tmp-ext-fs

fi

echo "Mounted the extfs formatted disk, starting to copy"

sudo cp -v -r -p ${IN_FOLDER}/* ./tmp-ext-fs

echo "Copying completed, syncing..."

sync

echo "Sync completed, Unmounting..."

sudo umount ./tmp-ext-fs

echo "Unmounting completed, removing the temp folder..."

# rm -rf ./tmp-ext-fs
