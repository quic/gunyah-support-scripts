#!/bin/bash

# © 2022 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

set -e

echo -e "\nLLVM TOOLS_DIR : $TOOLS_DIR"

TOOLS_SRC_DIR=$TOOLS_DIR/src
LLVM_TOOLS_SRC_DIR=${TOOLS_SRC_DIR}/llvm-tools

if [[ ! -d ${LLVM_TOOLS_SRC_DIR} ]] ; then

	mkdir -p ${LLVM_TOOLS_SRC_DIR}
	cd ${LLVM_TOOLS_SRC_DIR}

	# LLVM
	echo -e "\nCloning LLVM into : ${LLVM_TOOLS_SRC_DIR}"
	git clone \
	  --single-branch --depth=1 --progress -c advice.detachedHead=false -b \
	  release/15.x \
	  https://github.com/llvm/llvm-project.git || {
		echo "Unable to clone LLVM"
		return
	    }

	# MUSL
	echo -e "\nCloning MUSL into ${LLVM_TOOLS_SRC_DIR}"
	git clone -c advice.detachedHead=false -b v1.1.24 \
	    https://git.musl-libc.org/git/musl  || {
		echo "Unable to clone Musl"
		return
	    }
fi
