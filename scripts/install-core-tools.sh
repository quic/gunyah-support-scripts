#!/bin/bash

# © 2022 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

set -e

echo "Generate/build the tools"

echo "BASE_DIR : ${BASE_DIR}"
echo "TOOLS_DIR : ${TOOLS_DIR}"

if [[ -z "$USER" ]]; then
    echo "User is not set in Environment"
    export USER=`whoami`
fi

if [[ ! -d $(dirname "${TOOLS_DIR}") ]]; then
    echo "Tools volume not mounted"
    return
fi

if [[ ! -d ${TOOLS_DIR} ]]; then
    echo "Creating tools mount folder"
    sudo mkdir -p ${TOOLS_DIR}
    sudo chown $USER:$USER ${TOOLS_DIR}

    touch ${TOOLS_DIR}/.tools-env
    chmod 0775 ${TOOLS_DIR}/.tools-env
fi

if [[ ! -d ${TOOLS_DIR}/llvm ]]; then
    echo -e "\nLLVM toolchain not found..."

    echo -e 'export LLVM=${TOOLS_DIR}/llvm' >> ${TOOLS_DIR}/.tools-env
    echo -e 'export PATH=$PATH:$LLVM/bin' >> ${TOOLS_DIR}/.tools-env

    . ${TOOLS_DIR}/.tools-env

    . ${BASE_DIR}/core-utils/clone-llvm.sh
    . ${BASE_DIR}/core-utils/build-llvm.sh
fi

if [[ ! -d ${TOOLS_DIR}/qemu ]]; then
    echo -e "\nBuilding qemu tools"

    echo -e 'export QEMU_INSTALL_DIR=${TOOLS_DIR}/qemu' >> ${TOOLS_DIR}/.tools-env
    echo -e 'export QEMU=${QEMU_INSTALL_DIR}/bin/qemu-system-aarch64' >> ${TOOLS_DIR}/.tools-env
    echo -e 'export PATH=$PATH:$QEMU_INSTALL_DIR/bin' >> ${TOOLS_DIR}/.tools-env

    . ${TOOLS_DIR}/.tools-env

    . ${BASE_DIR}/core-utils/clone-qemu.sh
    . ${BASE_DIR}/core-utils/build-qemu.sh

fi

echo -e "Installation of the core tools is complete\n"
