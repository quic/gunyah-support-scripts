#!/bin/bash

# © 2022 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

set -e

echo -e "\nBuild Qemu from TOOLS_DIR : $TOOLS_DIR"
echo "QEMU_INSTALL_DIR : $QEMU_INSTALL_DIR"

CPU_CNT=$(grep -c ^processor /proc/cpuinfo)
echo -e "\nCPU_CNT:${CPU_CNT}"

TOOLS_SRC_DIR="${TOOLS_DIR}/src"

SLIRPLIB_FLAGS=" "

if [[ -d ${TOOLS_SRC_DIR}/libslirp ]]; then
	echo "Found libslirp, build and installing"

	SLIRPLIB_FLAGS=" --enable-slirp --static "

	cd ${TOOLS_SRC_DIR}/libslirp
	meson build --prefix=${QEMU_INSTALL_DIR}
	ninja -C build install
	cd ..
else
	echo "libslirp is not found..!!"
fi

if [[ ! -d ${TOOLS_SRC_DIR}/qemu ]]; then
    echo -e "\nqemu Sources do not exist here: ${TOOLS_SRC_DIR}"
    echo -e "\nrun clone-qemu.sh in utils"
	return
fi

cd $TOOLS_SRC_DIR

pushd qemu

# TODO: Fix it later and enable it back
SLIRPLIB_FLAGS=" "

mkdir -p build
cd build
echo -e "[BUILD] building and installing ''qemu''."
../configure \
	--prefix=${QEMU_INSTALL_DIR} \
	--target-list=aarch64-softmmu \
	--extra-cflags=-Wno-error \
	${SLIRPLIB_FLAGS} \
	--enable-debug  &&
	make -j${CPU_CNT}  &&
	make install  || {
	    echo "Failed."
            return
	}
popd >/dev/null

# Delete sources to save space, comment to retain sources
#rm -rf ${TOOLS_SRC_DIR}/qemu
