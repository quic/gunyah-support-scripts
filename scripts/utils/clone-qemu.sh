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


env_check TOOLS_DIR && checkenv_dir TOOLS_DIR

echo -e "\nTOOLS_DIR : ${TOOLS_DIR}"

mkdir -p ${TOOLS_DIR}/src

cd ${TOOLS_DIR}/src
rm -rf qemu

# QEMU
echo -e "\nCloning QEMU:"
git clone \
    --single-branch --depth=1 --progress -c advice.detachedHead=false \
    -b v7.2.0 \
    https://git.qemu.org/git/qemu.git  || {
	echo "Unable to clone QEMU"
	exit 1
    }

pushd qemu

git submodule init  || {
	echo "Unable to do submodule init"
	exit 1
    }

git submodule update --recursive --depth=1  || {
	echo "Unable to do submodule update"
	exit 1
    }

popd
