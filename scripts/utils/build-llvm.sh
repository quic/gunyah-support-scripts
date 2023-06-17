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


env_check TOOLS_DIR && checkenv_dir TOOLS_DIR

echo -e "\nTOOLS_DIR : ${TOOLS_DIR}"

LLVM_INSTALL_DIR="${LLVM}"
CPU_CNT=$(grep -c ^processor /proc/cpuinfo)
LLVM_SRC_BUILD_DIR="${TOOLS_DIR}/src/llvm-project"
MUSL_SRC_BUILD_DIR="${TOOLS_DIR}/src/musl"

if [[ ! -d ${LLVM_SRC_BUILD_DIR} ]]; then
    echo -e "\nllvm Sources do not exist here: ${LLVM_SRC_BUILD_DIR}"
    echo -e "\nrun clone-llvm.sh in utils"
	exit 1
fi

pushd ${LLVM_SRC_BUILD_DIR}/llvm
mkdir -p build
cd build

echo "Building LLVM $LLVM_SRC_BUILD_DIR"

cmake .. \
	-G Ninja \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=${LLVM_INSTALL_DIR} \
	-DLLVM_TARGETS_TO_BUILD="ARM;AArch64;X86" \
	-DLLVM_ENABLE_PROJECTS="llvm;clang;lld" \
	-DLLVM_ENABLE_BINDINGS=OFF \
	-DLLVM_LINK_LLVM_DYLIB=ON \
	-DLLVM_INSTALL_TOOLCHAIN_ONLY=ON &&
	ninja -j${CPU_CNT}  && 
	rm -rf ${LLVM_INSTALL_DIR}/* &&
	ninja install  || {
       		echo "Failed building LLVM"
		exit 1
       	}

echo "Done building LLVM, installed at ${LLVM_INSTALL_DIR}"
popd

LLVM_VERSION=$(${LLVM_SRC_BUILD_DIR}/llvm/build/bin/llvm-config --version | tr -d git)


echo "LLVM_VERSION : ${LLVM_VERSION}"

pushd ${MUSL_SRC_BUILD_DIR}
mkdir -p build
cd build
echo "Building musl lib"

CROSS_COMPILE=aarch64-linux-gnu- \
	CFLAGS="-march=armv8.5-a+rng" \
	LDFLAGS="-static" \
	../configure \
	--prefix=${LLVM_INSTALL_DIR}/aarch64-linux-gnu/libc \
	--build=aarch64-linux-gnu \
	--target=aarch64-linux-gnu \
	--enable-debug \
	--disable-optimize &&
	make &&
	make install || {
       		echo "Failed building musl lib"
		exit 1
	}

echo "Done building musl lib"
popd

export PATH=${LLVM_INSTALL_DIR}/bin:${PATH}

pushd ${LLVM_SRC_BUILD_DIR}/compiler-rt
mkdir -p build
cd build
echo "Install c runtime lib to llvm"

cmake .. \
	-G Ninja \
	-DCMAKE_AR=${LLVM_INSTALL_DIR}/bin/llvm-ar \
	-DCMAKE_ASM_COMPILER_TARGET=aarch64-linux-gnu \
	-DCMAKE_C_COMPILER=${LLVM_INSTALL_DIR}/bin/clang \
	-DCMAKE_C_COMPILER_TARGET=aarch64-linux-gnu \
	-DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld" \
	-DCMAKE_NM=${LLVM_INSTALL_DIR}/bin/llvm-nm \
	-DCMAKE_RANLIB=${LLVM_INSTALL_DIR}/bin/llvm-ranlib \
	-DCOMPILER_RT_BUILD_BUILTINS=ON \
	-DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
	-DCOMPILER_RT_BUILD_MEMPROF=OFF \
	-DCOMPILER_RT_BUILD_PROFILE=OFF \
	-DCOMPILER_RT_BUILD_SANITIZERS=OFF \
	-DCOMPILER_RT_BUILD_XRAY=OFF \
	-DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
	-DLLVM_CONFIG_PATH=${LLVM_SRC_BUILD_DIR}/llvm/build/bin/llvm-config \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=${LLVM_INSTALL_DIR}/lib/clang/${LLVM_VERSION}/ &&
	ninja -j${CPU_CNT} &&
	ninja install || {
       		echo "Failed to install runtime lib to llvm"
		exit 1
       	}

echo "Install c runtime lib to llvm done"
popd

# Delete the build to save disk space
rm -rf ${LLVM_SRC_BUILD_DIR}
rm -rf ${MUSL_SRC_BUILD_DIR}
