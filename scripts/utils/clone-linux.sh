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


env_check BASE_DIR && checkenv_dir BASE_DIR

echo -e "\nLINUX_DIR : ${LINUX_DIR}"

mkdir -p ${LINUX_DIR}/src
cd ${LINUX_DIR}/src

# LINUX
echo -e "\nCloning Linux v6.1:"
git clone \
    --single-branch --depth=1 --progress -c advice.detachedHead=false \
    -b v6.1  \
    https://github.com/torvalds/linux.git   || {
	echo "Unable to clone Linux"
	exit 1
    }

# RAMDISK
echo -e "\nDownloading Busybox:"
wget -c https://busybox.net/downloads/busybox-1.33.0.tar.bz2  || {
	echo "Unable to Download busybox"
	exit 1
    }

tar xf busybox-1.33.0.tar.bz2   || {
	echo "Unable to Uncompress busybox"
	exit 1
    }
