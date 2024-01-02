#!/bin/bash

# © 2022 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

set -e

echo "Building the workspace images"

echo "BASE_DIR : ${BASE_DIR}"
echo "TOOLS_DIR : ${TOOLS_DIR}"
echo "WORKSPACE : ${WORKSPACE}"
echo ""

if [[ -z "$USER" ]]; then
    echo "User is not set in Environment"
    export USER=`whoami`
fi

if [[ ! -d $(dirname "${WORKSPACE}") ]]; then
    echo "Workspace volume not mounted"
    return
fi

if [[ ! -d ${WORKSPACE} ]]; then

    echo "Creating workspace folder"
    sudo mkdir -p ${WORKSPACE}
    sudo chmod 0775 ${WORKSPACE}
    sudo chown $USER:$USER ${WORKSPACE}

    touch ${WORKSPACE}/.wsp-env
    chmod 0775 ${WORKSPACE}/.wsp-env

    echo -e 'if [[ -z "${USER}" ]]; then\n    export USER=`whoami`\nfi' >> ${WORKSPACE}/.wsp-env
    . ${WORKSPACE}/.wsp-env
fi

# Source the tools environment, otherwise builds fail which need LLVM
if [[ -f ${TOOLS_DIR}/.tools-env ]]; then
	echo "Sourcing tools environment"
	. ${TOOLS_DIR}/.tools-env
fi

# Source the workspace environment if its there
if [[ -f ${WORKSPACE}/.wsp-env ]]; then
	echo "Sourcing workspace environment"
	. ${WORKSPACE}/.wsp-env
fi

if [[ ! -d ${WORKSPACE}/imgs ]]; then
    mkdir -p ${WORKSPACE}/imgs

    echo -e 'export QEMU_IMGS_DIR=${WORKSPACE}/imgs' >> ${WORKSPACE}/.wsp-env
    . $WORKSPACE/.wsp-env
fi

if [[ ! -d ${WORKSPACE}/gunyah-venv ]]; then
    echo -e \n"Building gunyah venv"

    . ${BASE_DIR}/core-utils/build-py-vdev.sh

    . $WORKSPACE/.wsp-env
fi

if [[ ! -d ${WORKSPACE}/lib/app-sysroot ]]; then
    echo -e "\nBuilding app sysroot"

    echo -e 'export LIB_DIR=${WORKSPACE}/lib' >> ${WORKSPACE}/.wsp-env
    echo -e 'export LOCAL_SYSROOT=${LIB_DIR}/app-sysroot' >> ${WORKSPACE}/.wsp-env

    . $WORKSPACE/.wsp-env

    . ${BASE_DIR}/core-utils/clone-qcbor-dtc.sh
    . ${BASE_DIR}/core-utils/build-sysroot.sh
fi

if [[ -z "${LINUX_DIR}" ]]; then
    echo -e 'export LINUX_DIR=${WORKSPACE}/linux' >> ${WORKSPACE}/.wsp-env
    echo -e 'export RAMDISK_FILE_PATH=${LINUX_DIR}/initrd.img' >> ${WORKSPACE}/.wsp-env

    . $WORKSPACE/.wsp-env
fi

if [[ ! -d $LINUX_DIR ]]; then
    echo "Building Linux kernel and Ramdisk image"

    . ${BASE_DIR}/core-utils/clone-linux.sh
    . ${BASE_DIR}/core-utils/build-linux.sh
    . ${BASE_DIR}/core-utils/build-ramdisk.sh
fi

# Copy scripts to destinations
if [[ ! -f ${WORKSPACE}/kern-test.sh ]]; then
    cp ${BASE_DIR}/utils/kern-test.sh ${WORKSPACE}/kern-test.sh
fi

if [[ ! -f ${WORKSPACE}/run-qemu.sh ]]; then
    cp ${BASE_DIR}/utils/run-qemu.sh ${WORKSPACE}/run-qemu.sh
fi

if [[ ! -f ${WORKSPACE}/crosvm/crosvm ]]; then
    mkdir -p ${WORKSPACE}/crosvm
    cd ${WORKSPACE}/crosvm
    . clone-crosvm.sh
    . build-crosvm.sh

    echo -e 'export CROSVM_FILE_PATH=${WORKSPACE}/crosvm/crosvm' >> ${WORKSPACE}/.wsp-env
    . ${WORKSPACE}/.wsp-env
fi

if [[ ! -f ${WORKSPACE}/rootfs/rootfs-extfs-disk.img ]]; then
    echo -e "\nrootfs image not found, creating new one"
    . build-rootfs-img.sh

    echo -e 'export VIRTIO_DEVICE_FILE=${WORKSPACE}/rootfs/rootfs-extfs-disk.img' >> ${WORKSPACE}/.wsp-env
    . ${WORKSPACE}/.wsp-env
fi

echo "Installation of the workspace images is completed"
