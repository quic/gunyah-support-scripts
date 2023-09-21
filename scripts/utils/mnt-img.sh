#!/bin/bash

# © 2023 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

MOUNT_FOLDER="./tmpfs-mnt"
VALID_ARGS=$(getopt -o f: --long folder: -- "$@")

if [[ $# -lt 1 ]]; then
	echo -e "Usage: $(basename $0) [options] <Image file name>"
	echo -e "Options:"
	echo -e "\t -f|--folder  path : Folder path to mount on"
	exit 1;
fi

eval set -- "$VALID_ARGS"
while [ : ]; do
  case "$1" in
    -f | --folder)
	MOUNT_FOLDER=$2
        #echo "Input folder: ${IN_FOLDER}"
        shift 2
        ;;
    --) shift; 
        break 
        ;;
  esac
done


mkdir -p $MOUNT_FOLDER

if [[ $# -eq 0 ]]; then
    >&2 echo "Need image file as argument"
    exit 1
fi

if [[ ! -f $1 ]]; then
    >&2 echo "Image file $1 not found"
    exit 1
fi

FILE_TYPE=`file $1`
# output of above command should determine how we handle below
#echo $FILE_TYPE

GZ_COMPRESSED=`echo $FILE_TYPE | grep "gzip compressed"`

FILE_TO_MOUNT=$1

#echo $GZ_COMPRESSED
if [[ ! -z $GZ_COMPRESSED ]]; then
    echo "gz Compressed image"
    ARG_FILE=$1
    UNC_OP_FILE=${ARG_FILE%%.*}-uc.${ARG_FILE##*.}
    cp $ARG_FILE $UNC_OP_FILE.gz
    gunzip -v $UNC_OP_FILE
    FILE_TO_MOUNT=$UNC_OP_FILE
    FILE_TYPE=`file $FILE_TO_MOUNT`
fi

EXT_FS_TYPE=`echo $FILE_TYPE | grep "ext4 filesystem"`
CPIO_ARCHIVE_TYPE=`echo $FILE_TYPE | grep "cpio archive"`

#echo $EXT_FS_TYPE
if [[ ! -z $EXT_FS_TYPE ]]; then
    echo "Extfs image"
    # Linux rev 1.0 ext4 filesystem data
    sudo mount -o loop $FILE_TO_MOUNT $MOUNT_FOLDER

    echo "Mounted the device with extfs to $MOUNT_FOLDER"
    echo "exit shell to unmount after examining files "
    bash

    sudo umount $MOUNT_FOLDER
    rm -rf $MOUNT_FOLDER
fi

#echo $CPIO_ARCHIVE_TYPE
if [[ ! -z $CPIO_ARCHIVE_TYPE ]]; then
    echo "cpio archive image"
    # ASCII cpio archive (SVR4 with no CRC)
    cd $MOUNT_FOLDER
    cat ../$FILE_TO_MOUNT | cpio -idmv

    echo "Extracted cpio files into this folder, delete the folder after done"
    echo "rm -rf $MOUNT_FOLDER"
    echo "rm -f $FILE_TO_MOUNT"
fi
