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
        exit 2
    fi
}

env_check TOOLS_DIR && checkenv_dir TOOLS_DIR

echo -e "\nTOOLS_DIR : $TOOLS_DIR"

mkdir -p ${TOOLS_DIR}/src
cd ${TOOLS_DIR}/src

# LLVM
echo -e "\nCloning LLVM:"
git clone \
  --single-branch --depth=1 --progress -c advice.detachedHead=false -b \
  release/15.x \
  https://github.com/llvm/llvm-project.git  || {
	echo "Unable to clone LLVM"
	exit 3
    }

# MUSL
echo -e "\nCloning MUSL:"
git clone -c advice.detachedHead=false -b v1.1.24 \
    https://git.musl-libc.org/git/musl  || {
	echo "Unable to clone Musl"
	exit 4
    }

