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
        echo -e "\nDirectory Doesn't Exists : $DIR"
        exit 1
    fi
}

env_check TOOLS_DIR && checkenv_dir TOOLS_DIR

echo -e "\nTOOLS_DIR : $TOOLS_DIR"

CPU_CNT=$(grep -c ^processor /proc/cpuinfo)
echo -e "\nCPU_CNT:${CPU_CNT}"

echo -e "\nBuilding Qemu"

SRC_DIR="${TOOLS_DIR}/src"

if [[ ! -d ${SRC_DIR}/qemu ]]; then
    echo -e "\nqemu Sources do not exist here: ${SRC_DIR}"
    echo -e "\nrun clone-qemu.sh in utils"
	exit 1
fi

cd $SRC_DIR

pushd qemu

mkdir -p build
cd build
echo -e "[BUILD] building and installing ''qemu''."
../configure \
	--prefix=${QEMU_INSTALL_DIR} \
	--target-list=aarch64-softmmu \
	--extra-cflags=-Wno-error \
	--enable-debug  &&
	make -j${CPU_CNT}  &&
	mkdir -p ${QEMU_IMGS_DIR}  &&
	make install  || {
	    echo "Failed."
            exit 1
	}
popd >/dev/null


