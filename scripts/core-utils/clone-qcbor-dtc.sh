#!/bin/bash

# © 2022 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

set -e

echo -e "\nCloning QCBOR and fdt lib for sys_root into LIB_DIR : $LIB_DIR"
echo "BASE_DIR : $BASE_DIR"

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
	return
    }

pushd QCBOR

echo -e "\napplying QCBOR patch"

git apply "${BASE_DIR}/core-utils/gunyah-qcbor.patch"  || {
	echo "Unable to apply qcbor gunyah patch to QCBOR"
	return
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
	return
    }
