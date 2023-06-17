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


env_check BASE_DIR && checkenv_dir BASE_DIR

echo -e "\nLIB_DIR : $LIB_DIR"

SRC_DIR="${LIB_DIR}/src"

if [[ ! -d ${SRC_DIR} ]]; then
    echo -e "\nQCBOR Sources do not exist here: ${SRC_DIR}"
    echo -e "\nrun clone-qcbor-dtc.sh in utils"
fi

cd $SRC_DIR

echo "[BUILD] building and installing ''dtc''."

if [[ ! -d ${SRC_DIR}/dtc ]]; then
    echo -e "\ndtc Sources do not exist here: ${SRC_DIR}"
    echo -e "\nrun clone-qcbor-dtc.sh in utils"
	exit 1
fi

pushd dtc

CC=aarch64-linux-gnu-gcc make  &&
CC=aarch64-linux-gnu-gcc make install libfdt \
    PREFIX=${LOCAL_SYSROOT}  || {
	echo "Failed building app-sysroot"
	exit 1
    }

popd >/dev/null


if [[ ! -d ${SRC_DIR}/QCBOR ]]; then
    echo -e "\nQCBOR Sources do not exist here: ${SRC_DIR}"
    echo -e "\nrun clone-qcbor-dtc.sh in utils"
	exit 1
fi

pushd QCBOR

echo "[BUILD] building and installing ''QCBOR''."

make -f Makefile.hyp sysroot_decoder_lib

echo "Built decoder lib"

popd >/dev/null

