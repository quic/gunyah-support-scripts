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
Build Gunyah hypervisor, resource manager, and runtime.
      --remote            set remote address to clone repositories.
      --hypervisor        set hypervisor repository and branch as ''REPO,BRANCH''.
      --c-runtime         set runtime repository and branch as ''REPO,BRANCH''.
      --resource-manager  set resource manager repository and branch as ''REPO,BRANCH''.

    Build arguments
      --platform          set platform, currently only supported for ''qemu''
      --featureset        set available features, currently only supported for ''gunyah-rm-qemu''
      --quality           set build type, currently supporting for ''debug'' and ''release''

      --log=FILE      log file.
EOF
}

default_log() {
    echo "/dev/null"
}

default_remote() {
    echo "https://github.com/quic/"
}

default_hypervisor() {
    echo "gunyah-hypervisor.git,develop"
}

default_runtime() {
    echo "gunyah-resource-manager.git,develop"
}

default_rm() {
    echo "gunyah-c-runtime.git,develop"
}

parse_argument remote:,hypervisor:,c-runtime:,resource-manager:,platform:,featureset:,quality:,log:,help "$@"

get_argument remote REMOTE default_remote
get_argument hypervisor HYPERVISOR default_hypervisor
get_argument c-runtime C_RUNTIME default_runtime
get_argument resource-manager RM default_rm

get_argument platform PLATFORM
get_argument featureset FEATURESET
get_argument quality QUALITY

if [[ ! -v PLATFORM ||
    ! -v FEATURESET ||
    ! -v QUALITY ]]; then
    show_usage
    exit 0
fi

get_argument log LOG default_log
get_argument help HELP

rm -rf .repos
mkdir .repos

IFS=',' read -r -a HYPERVISOR <<<${HYPERVISOR}
IFS=',' read -r -a C_RUNTIME <<<${C_RUNTIME}
IFS=',' read -r -a RM <<<${RM}

git_clone ${REMOTE} "--quiet" \
    ${HYPERVISOR[@]} \
    ${C_RUNTIME[@]} \
    ${RM[@]} || {
    die "''git clone'' failed."
}

gunyah_build() {
    echo "Building ${1} ..."

    pushd .repos/${1} >/dev/null
    ./configure.py \
        platform=${PLATFORM} \
        featureset=${FEATURESET} \
        quality=${QUALITY} &>>${LOG} &&
        ninja &>>${LOG}
    popd >/dev/null
}

gunyah_build ${RM[0]}
gunyah_build ${C_RUNTIME[0]}
gunyah_build ${HYPERVISOR[0]}

$LLVM/bin/llvm-strip ${RM[0]//[-.]/_}/build/qemu/debug/resource-manager -o ${RM[0]//[-.]/_}/build/qemu/debug/resource-manager.strip
$LLVM/bin/llvm-strip ${C_RUNTIME[0]//[-.]/_}/build/runtime -o ${C_RUNTIME[0]//[-.]/_}/build/runtime.strip
