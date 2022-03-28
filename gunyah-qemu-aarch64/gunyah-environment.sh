#!/bin/bash

# © 2021 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

source "$(
	cd "$(dirname "$0")" >/dev/null 2>&1
	pwd -P
)"/common.sh

show_usage() {
	cat <<EOF
Usage: ${PROGNAME} [OPTION]
Prepare enviornment for Gunyah compilation and simulation.
      --toolchain     build and install llvm and compiler-rt.
      --qemu          build and install qemu.
      --build-deps    build ans install Gunyah dependencies
      --install=PATH  path to install tools.
      --log=FILE      log file.
EOF
}

default_log() {
	echo "/dev/null"
}

default_install() {
	echo "install"
}

parse_argument toolchain,qemu,deps,install:,log:,help "$@"

get_argument toolchain TOOLCHAIN                 # ... request building toolchain
get_argument qemu QEMU                           # ... request building qemu
get_argument deps DEPS                           # ... request building gunyah dependencies
get_argument install INSTALL_DIR default_install # ... installation path
get_argument log LOG default_log
get_argument help HELP

if [[ -v HELP ]]; then
	show_usage
	exit 0
fi

INSTALL_DIR=$(readlink -f ${INSTALL_DIR})
LOG=$(readlink -f ${LOG})

echo "[LOG] ''${LOG}''"
echo "[INSTALL] ''${INSTALL_DIR}''"

rm -rf .repos
mkdir -p ${INSTALL_DIR}/hypervisor .repos

touch ${INSTALL_DIR}/hypervisor/source

if [[ -v TOOLCHAIN ]]; then
	git_clone "git://git.musl-libc.org/" \
		"--quiet -c advice.detachedHead=false" \
		"musl" \
		"v1.1.24" || {
		die "Unable to clone musl-libc."
	}

	git_clone "https://github.com/llvm/" \
		"--progress" \
		"llvm-project.git" \
		"release/13.x" || {
		die "Unable to clone llvm."
	}

	pushd ${llvm_project_git}/llvm >/dev/null
	mkdir build
	cd build

	echo "[BUILD] building and installing ''llvm'' and ''clang''."
	cmake .. \
		-G Ninja \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
		-DLLVM_TARGETS_TO_BUILD="ARM;AArch64;X86" \
		-DLLVM_ENABLE_PROJECTS="llvm;clang;lld" \
		-DLLVM_ENABLE_BINDINGS=OFF \
		-DLLVM_LINK_LLVM_DYLIB=ON \
		-DLLVM_INSTALL_TOOLCHAIN_ONLY=ON &>>${LOG} &&
		ninja -j$(grep -c ^processor /proc/cpuinfo) &>>${LOG} &&
		ninja install &>>${LOG} || {
		die "Failed."
	}
	popd >/dev/null

	export VERSION=$(
		${llvm_project_git}/llvm/build/bin/llvm-config --version |
			tr -d git
	)

	pushd ${musl} >/dev/null
	mkdir build
	cd build

	echo "[BUILD] building and installing ''musl-libc''."
	CROSS_COMPILE=aarch64-linux-gnu- \
		CFLAGS="-march=armv8.5-a+rng" \
		LDFLAGS="-static" \
		../configure \
		--prefix=${INSTALL_DIR}/aarch64-linux-gnu/libc \
		--build=aarch64-linux-gnu \
		--target=aarch64-linux-gnu \
		--enable-debug \
		--disable-optimize &>>${LOG} &&
		make &>>${LOG} &&
		make install &>>${LOG} || {
		die "Failed."
	}
	popd >/dev/null

	export PATH=${INSTALL_DIR}/bin:${PATH}

	pushd ${llvm_project_git}/compiler-rt >/dev/null
	mkdir build
	cd build

	echo "[BUILD] building and installing ''compiler-rt''."
	cmake .. \
		-G Ninja \
		-DCMAKE_AR=${INSTALL_DIR}/bin/llvm-ar \
		-DCMAKE_ASM_COMPILER_TARGET=aarch64-linux-gnu \
		-DCMAKE_C_COMPILER=${INSTALL_DIR}/bin/clang \
		-DCMAKE_C_COMPILER_TARGET=aarch64-linux-gnu \
		-DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld" \
		-DCMAKE_NM=${INSTALL_DIR}/bin/llvm-nm \
		-DCMAKE_RANLIB=${INSTALL_DIR}/bin/llvm-ranlib \
		-DCOMPILER_RT_BUILD_BUILTINS=ON \
		-DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
		-DCOMPILER_RT_BUILD_MEMPROF=OFF \
		-DCOMPILER_RT_BUILD_PROFILE=OFF \
		-DCOMPILER_RT_BUILD_SANITIZERS=OFF \
		-DCOMPILER_RT_BUILD_XRAY=OFF \
		-DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
		-DLLVM_CONFIG_PATH=${llvm_project_git}/llvm/build/bin/llvm-config \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/lib/clang/${VERSION}/ &>>${LOG} &&
		ninja -j$(grep -c ^processor /proc/cpuinfo) &>>${LOG} &&
		ninja install &>>${LOG} || {
		die "Failed."
	}
	popd >/dev/null

	rm -rf ${llvm_project_git} ${musl}
	echo "export LLVM=${INSTALL_DIR}" >>${INSTALL_DIR}/hypervisor/source
fi

if [[ -v QEMU ]]; then
	git_clone "https://git.qemu.org/git/" \
		"--quiet  -c advice.detachedHead=false" \
		"qemu.git" \
		"v6.0.1" || {
		die "Unable to clone qemu."
	}

	pushd ${qemu_git} >/dev/null
	git submodule init &>>${LOG} || {
		die "''git submodule init'' failed."
	}

	git submodule update --recursive &>>${LOG} || {
		die "''git submodule update --recursive'' failed."
	}

	mkdir build
	cd build
	echo "[BUILD] building and installing ''qemu''."
	../configure \
		--prefix=${INSTALL_DIR} \
		--target-list=aarch64-softmmu \
		--enable-debug &>>${LOG} &&
		make &>>${LOG} &&
		make install &>>${LOG} || {
		die "Failed."
	}
	popd >/dev/null

	rm -rf ${qemu_git}
	echo "export QEMU=${INSTALL_DIR}/bin/qemu-system-aarch64" \
		>>${INSTALL_DIR}/hypervisor/source
fi

if [[ -v DEPS ]]; then
	git_clone "https://github.com/dgibson/" \
		"--quiet" \
		"dtc.git" \
		"main" || {
		die "Unable to clone dtc."
	}

	pushd ${dtc_git} >/dev/null

	echo "[BUILD] building and installing ''dtc''."
	CC=aarch64-linux-gnu-gcc make &>>${LOG} &&
		CC=aarch64-linux-gnu-gcc make install libfdt \
			PREFIX=${INSTALL_DIR}/hypervisor/c-application-sysroot &>>${LOG} || {
		die "Failed."
	}
	popd >/dev/null
	echo "export LOCAL_SYSROOT=${INSTALL_DIR}/hypervisor/c-application-sysroot" \
		>>${INSTALL_DIR}/hypervisor/source

	rm -rf ${dtc_git}

	pushd ${INSTALL_DIR}/hypervisor >/dev/null

	echo "[BUILD] preparing python venv."
	python3 -m venv gunyah-venv &&
		chmod a+x gunyah-venv/bin/activate &&
		. gunyah-venv/bin/activate &&
		pip3 install --upgrade pip &&
		pip3 install wheel &&
		pip3 install lark_parser &&
		pip3 install Cheetah3 &&
		pip3 install pyelftools || {
		die "Faild."
	}

	popd >/dev/null
	echo "source ${INSTALL_DIR}/hypervisor/gunyah-venv/bin/activate" \
		>>${INSTALL_DIR}/hypervisor/source
fi

echo "Done."
echo "Run ''. ${INSTALL_DIR}/hypervisor/source''"
