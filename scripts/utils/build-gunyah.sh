#!/bin/bash

# © 2022 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

set -e

if [[ -z "$LOCAL_SYSROOT" ]]; then
    echo "LOCAL_SYSROOT is not found"
    exit 1
fi

if [[ $# -eq 0 ]]; then
    PLATFORM=qemu
    echo "Building qemu as default platform"
    #exit 1
else
    PLATFORM=$1
fi

CLEAN=0
if [ ! -z $2 ]; then
	if [[ $2 == "clean" ]]; then
		CLEAN=1
	else
		echo "Second argument should be clean or not provided"
		exit 1
	fi
fi

if [[ -f ./${PLATFORM}/hypvm.elf ]]; then
    rm -f  ./${PLATFORM}/hypvm.elf
    echo "Deleted the ${PLATFORM} hypvm.elf file"
fi

if [[ ${PLATFORM} == "qemu" ]]; then
	FEATURE=gunyah-rm-qemu
fi

QUALITY=debug

if [[ ${CLEAN} == 1 ]]; then
	rm -rf hyp/build/${PLATFORM}
	rm -rf resource-manager/build/${PLATFORM}
	rm -rf musl-c-runtime/build
	rm -rf ${PLATFORM}/*
fi

cd hyp
echo "./configure.py platform=${PLATFORM} featureset=${FEATURE} quality=${QUALITY} ; ninja"
./configure.py platform=${PLATFORM} featureset=${FEATURE} quality=${QUALITY} ; ninja
cp build/${PLATFORM}/${FEATURE}/${QUALITY}/hyp.elf build/${PLATFORM}/${FEATURE}/${QUALITY}/hyp.strip.elf
$LLVM/bin/llvm-strip -d build/${PLATFORM}/${FEATURE}/${QUALITY}/hyp.strip.elf

cd ../resource-manager
echo "./configure.py platform=${PLATFORM} featureset=${FEATURE} quality=${QUALITY} ; ninja"
./configure.py platform=${PLATFORM} featureset=${FEATURE} quality=${QUALITY} ; ninja
cp build/${PLATFORM}/${QUALITY}/resource-manager build/${PLATFORM}/${QUALITY}/resource-manager.elf
cp build/${PLATFORM}/${QUALITY}/resource-manager.elf build/${PLATFORM}/${QUALITY}/resource-manager.strip.elf
$LLVM/bin/llvm-strip -d build/${PLATFORM}/${QUALITY}/resource-manager.strip.elf

cd ../musl-c-runtime
echo "./configure.py platform=${PLATFORM} featureset=${FEATURE} quality=${QUALITY} ; ninja"
./configure.py platform=${PLATFORM} featureset=${FEATURE} quality=${QUALITY} ; ninja
cp build/runtime build/runtime.strip.elf
$LLVM/bin/llvm-strip -d build/runtime.strip.elf

cd ..

if [[ ! -d ${PLATFORM} ]]; then
    mkdir -p ${PLATFORM}
fi

python3 hyp/tools/elf/package_apps.py \
    -a resource-manager/build/${PLATFORM}/debug/resource-manager.strip.elf \
    -r musl-c-runtime/build/runtime.strip.elf \
    hyp/build/${PLATFORM}/${FEATURE}/debug/hyp.strip.elf \
    -o ${PLATFORM}/hypvm.elf

echo "created ${PLATFORM}/hypvm.elf"


if [[ -f ${PLATFORM}/hypvm.elf ]]; then
    if [[ -z ${QEMU_IMGS_DIR} ]]; then
	echo "Environment variable QEMU_IMGS_DIR is not set, to copy image to test destination"
    else
	cp ${PLATFORM}/hypvm.elf ${QEMU_IMGS_DIR}/hypvm.elf
	echo "Copied hypvm.elf to ${QEMU_IMGS_DIR}/hypvm.elf"
    fi
fi
