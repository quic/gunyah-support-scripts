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

echo -e "\nLIB_DIR : $LIB_DIR"

mkdir -p ${LIB_DIR}/src
cd ${LIB_DIR}/src
rm -rf QCBOR dtc

# QCBOR
echo -e "\nCloning QCBOR:"
git clone \
  --single-branch --depth=1 --progress --quiet -c advice.detachedHead=false \
    -b v1.2 \
    https://github.com/laurencelundblade/QCBOR.git || {
	echo "Unable to clone QCBOR"
	exit 1
    }

pushd QCBOR

echo -e "\napplying QCBOR patch"

git apply "${BASE_DIR}/utils/gunyah-qcbor.patch"  || {
	echo "Unable to apply qcbor gunyah patch to QCBOR"
	exit 1
}
echo -e "\nDone applying patch"

popd >/dev/null

# DTC
echo -e "\nCloning DTC:"
git clone \
  --single-branch --progress --quiet -c advice.detachedHead=false -b \
    v1.6.1 \
    https://github.com/dgibson/dtc.git  || {
	echo "Unable to clone DTC"
	exit 1
    }
