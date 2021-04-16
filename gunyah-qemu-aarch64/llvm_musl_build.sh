#!/bin/sh

# Ensure this script aborts on errors
set -ex

WORKING_DIR=$PWD
AARCH64_TRIPLE=aarch64-linux-gnu
BUILD_DIR=${WORKING_DIR}/llvm-musl
INSTALL_DIR=${WORKING_DIR}/llvm-musl-install
TRIPLE_INSTALL_DIR=${INSTALL_DIR}/${AARCH64_TRIPLE}
LLVM_DIR=${BUILD_DIR}/llvm-project
MUSL_DIR=${BUILD_DIR}/musl-1.1.24

# Remove previous builds
rm -rf ${BUILD_DIR}
rm -rf ${INSTALL_DIR}

# Create new build
mkdir ${BUILD_DIR}

# Get LLVM (10.x) and build it with support for x86, ARM, and AArch64
cd ${BUILD_DIR}
git clone --single-branch --branch=release/10.x https://github.com/llvm/llvm-project.git

cd ${LLVM_DIR}/llvm
mkdir build
cd build
cmake \
    .. \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
    -DLLVM_TARGETS_TO_BUILD="ARM;AArch64;X86" \
    -DLLVM_ENABLE_PROJECTS="llvm;clang;polly;lld;" \
    -DLLVM_ENABLE_BINDINGS=Off \
    -DLIBCLANG_BUILD_STATIC=ON \
    -DLLVM_BUILD_LLVM_DYLIB=On \
    -DLLVM_LINK_LLVM_DYLIB=On \
    -DLLVM_INSTALL_TOOLCHAIN_ONLY=On
ninja
ninja install

# Get musl libc (1.1.24) and build it for aarch64
cd ${BUILD_DIR}
wget http://musl.libc.org/releases/musl-1.1.24.tar.gz
tar -xvf musl-1.1.24.tar.gz
rm -rf musl-1.1.24.tar.gz

cd ${MUSL_DIR}
mkdir build-aarch64
cd build-aarch64
CROSS_COMPILE=aarch64-linux-gnu- \
    CFLAGS="-march=armv8.5-a+rng" \
    LDFLAGS="-static" \
    ../configure \
    --prefix=${TRIPLE_INSTALL_DIR}/libc \
    --build=aarch64-linux-gnu \
    --target=aarch64-linux-gnu \
    --enable-debug \
    --disable-optimize
make install

# Use generated binaries
export PATH=${TRIPLE_INSTALL_DIR}/bin:${INSTALL_DIR}/bin:${PATH}

C_COMPILER=${INSTALL_DIR}/bin/clang
CXX_COMPILER=${INSTALL_DIR}/bin/clang++

EXTRA_FLAGS="${EXTRA_FLAGS} -isystem ${TRIPLE_INSTALL_DIR}/libc/include"
EXTRA_FLAGS="${EXTRA_FLAGS} -I ${TRIPLE_INSTALL_DIR}/include"
EXTRA_FLAGS="${EXTRA_FLAGS} -L ${TRIPLE_INSTALL_DIR}/lib"

# Build libunwind
cd ${LLVM_DIR}/libunwind
mkdir build
cd build
cmake \
    .. \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=${TRIPLE_INSTALL_DIR} \
    -DCMAKE_C_COMPILER=${C_COMPILER} \
    -DCMAKE_CXX_COMPILER=${CXX_COMPILER} \
    -DCMAKE_C_FLAGS="${EXTRA_FLAGS}" \
    -DCMAKE_CXX_FLAGS="${EXTRA_FLAGS}" \
    -DLLVM_ENABLE_LIBCXX=ON \
    -DLLVM_CONFIG_PATH=${LLVM_DIR}/llvm/build/bin/llvm-config
ninja
ninja install

# Libcxxabi requires libcxx to build, but we will later need to build libcxx
# using libcxxabi. Due to this dependency we need to first build an initial
# version of libcxx.

# Build initial libcxx (with MUSL_LIBC)
cd ${LLVM_DIR}/libcxx
mkdir init-build
cd init-build
cmake \
    .. \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=${TRIPLE_INSTALL_DIR} \
    -DCMAKE_C_COMPILER=${C_COMPILER} \
    -DCMAKE_CXX_COMPILER=${CXX_COMPILER} \
    -DCMAKE_C_FLAGS="${EXTRA_FLAGS}" \
    -DCMAKE_CXX_FLAGS="${EXTRA_FLAGS}" \
    -DLIBCXX_HAS_MUSL_LIBC=ON \
    -DLLVM_CONFIG_PATH=${LLVM_DIR}/llvm/build/bin/llvm-config
ninja
ninja install

# Build libcxxabi with initial libcxx build
cd ${LLVM_DIR}/libcxxabi
mkdir build
cd build
cmake \
    .. \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=${TRIPLE_INSTALL_DIR} \
    -DCMAKE_C_COMPILER=${C_COMPILER} \
    -DCMAKE_CXX_COMPILER=${CXX_COMPILER} \
    -DCMAKE_C_FLAGS="${EXTRA_FLAGS}" \
    -DCMAKE_CXX_FLAGS="${EXTRA_FLAGS}" \
    -DLIBCXXABI_ENABLE_PIC=ON \
    -DLIBCXXABI_ENABLE_STATIC_UNWINDER=OFF \
    -DLIBCXXABI_LIBCXX_PATH=${TRIPLE_INSTALL_DIR} \
    -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
    -DLIBCXXABI_LIBUNWIND_PATH="${LLVM}/libunwind" \
    -DLIBCXXABI_LIBUNWIND_INCLUDES="${LLVM}/libunwind/include" \
    -DLLVM_CONFIG_PATH=${LLVM_DIR}/llvm/build/bin/llvm-config
ninja
ninja install

# Build libcxx (with MUSL_LIBC) using the libcxxabi build.
cd ${LLVM_DIR}/libcxx
mkdir build
cd build
cmake \
    .. \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=${TRIPLE_INSTALL_DIR} \
    -DCMAKE_C_COMPILER=${C_COMPILER} \
    -DCMAKE_CXX_COMPILER=${CXX_COMPILER} \
    -DCMAKE_C_FLAGS="${EXTRA_FLAGS}" \
    -DCMAKE_CXX_FLAGS="${EXTRA_FLAGS}" \
    -DLIBCXX_CXX_ABI=libcxxabi \
    -DLIBCXX_CXX_ABI_INCLUDE_PATHS="${LLVM_DIR}/libcxxabi/include" \
    -DLIBCXX_CXX_ABI_LIBRARY_PATH="${TRIPLE_INSTALL_DIR}/lib" \
    -DLIBCXX_HAS_MUSL_LIBC=ON \
    -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
    -DLLVM_CONFIG_PATH=${LLVM_DIR}/llvm/build/bin/llvm-config
ninja
ninja install

VERSION=$(${LLVM_DIR}/llvm/build/bin/llvm-config --version | tr -d git)

# Build compiler-rt
cd ${LLVM_DIR}/compiler-rt
mkdir build
cd build
cmake \
    .. \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/lib/clang/${VERSION}/ \
    -DCMAKE_C_COMPILER=${INSTALL_DIR}/bin/clang \
    -DCMAKE_CXX_COMPILER=${INSTALL_DIR}/bin/clang++ \
    -DCMAKE_C_FLAGS="${EXTRA_FLAGS}" \
    -DCMAKE_CXX_FLAGS="${EXTRA_FLAGS}" \
    -DCOMPILER_RT_BUILD_BUILTINS=ON \
    -DCOMPILER_RT_BUILD_SANITIZERS=OFF \
    -DCOMPILER_RT_BUILD_XRAY=OFF \
    -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
    -DCOMPILER_RT_BUILD_PROFILE=OFF \
    -DCMAKE_AR=${INSTALL_DIR}/bin/llvm-ar \
    -DCMAKE_NM=${INSTALL_DIR}/bin/llvm-nm \
    -DCMAKE_RANLIB=${INSTALL_DIR}/bin/llvm-ranlib \
    -DCMAKE_C_COMPILER_TARGET="${AARCH64_TRIPLE}" \
    -DCMAKE_ASM_COMPILER_TARGET="${AARCH64_TRIPLE}" \
    -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
    -DLLVM_CONFIG_PATH=${LLVM_DIR}/llvm/build/bin/llvm-config
ninja
ninja install

cd ${WORKING_DIR}
rm -rf ${BUILD_DIR}
