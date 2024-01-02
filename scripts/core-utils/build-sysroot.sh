#!/bin/bash

# © 2022 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

set -e

echo -e "\nBuilding sysroot from LIB_DIR : $LIB_DIR"
echo "LLVM : $LLVM"
echo "LOCAL_SYSROOT : ${LOCAL_SYSROOT}"

SRC_DIR="${LIB_DIR}/src"

if [[ ! -d ${SRC_DIR}/dtc ]] || [[ ! -d ${SRC_DIR}/QCBOR ]]; then
	echo -e "\ndtc/QCBOR Sources not found in : ${SRC_DIR}"
	return
fi

cd $SRC_DIR

echo "[BUILD] building and installing ''dtc''."

pushd dtc

CC=aarch64-linux-gnu-gcc make  &&
CC=aarch64-linux-gnu-gcc make install libfdt \
    PREFIX=${LOCAL_SYSROOT}  || {
	echo "Failed building app-sysroot"
	return
    }

popd >/dev/null

echo "[BUILD] building and installing ''QCBOR''."

pushd QCBOR

make -f Makefile.hyp sysroot_decoder_lib

echo "Built decoder lib"

popd >/dev/null
