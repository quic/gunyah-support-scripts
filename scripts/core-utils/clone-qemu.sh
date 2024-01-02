#!/bin/bash

# © 2022 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

set -e

echo -e "\nClone QEMU to TOOLS_DIR : $TOOLS_DIR"

TOOLS_SRC_DIR=${TOOLS_DIR}/src

mkdir -p ${TOOLS_SRC_DIR}

if [[ ! -d ${TOOLS_SRC_DIR}/qemu ]] ; then

	cd ${TOOLS_SRC_DIR}

	# QEMU
	echo -e "\nCloning QEMU:"
	git clone \
	    --single-branch --depth=1 --progress -c advice.detachedHead=false \
	    -b v7.2.0 \
	    https://git.qemu.org/git/qemu.git  || {
		echo "Unable to clone QEMU"
		return
	    }

	pushd qemu

	git submodule init  || {
		echo "Unable to do submodule init"
		return
	    }

	git submodule update --recursive --depth=1  || {
		echo "Unable to do submodule update"
		return
	    }

	popd
fi

if [[ ! -d ${TOOLS_SRC_DIR}/libslirp ]] ; then
	# download libslirp to enable networking
	git clone https://gitlab.freedesktop.org/slirp/libslirp.git
fi
