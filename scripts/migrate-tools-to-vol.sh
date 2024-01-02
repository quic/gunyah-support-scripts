#!/bin/bash

# © 2022 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

# This script will run in the Old docker image instance to migrate the tools
# that were built during original old docker image generation, thus saving
# time and space to generate newer version of docker images using new scripts

set -e

echo "Migrating the old tools/data into volumes for usage in the new container"

WORKSPACE="${BASE_DIR}/mnt/workspace"
NEW_TOOLS_DIR="/usr/local/mnt/tools"

if [[ ! -d ${NEW_TOOLS_DIR} ]]; then
    echo "Creating tools mount folder"
    sudo mkdir -p ${NEW_TOOLS_DIR}

    sudo touch ${NEW_TOOLS_DIR}/.tools-env
    sudo chmod 0777 ${NEW_TOOLS_DIR}/.tools-env
fi

if [[ ! -d ${NEW_TOOLS_DIR}/llvm ]]; then
    echo "Copying llvm folder to tools volume"
    sudo cp -r /usr/local/llvm ${NEW_TOOLS_DIR}/

    sudo echo -e 'export LLVM=${TOOLS_DIR}/llvm' >> ${NEW_TOOLS_DIR}/.tools-env
    sudo echo -e 'export PATH=$PATH:$LLVM/bin' >> ${NEW_TOOLS_DIR}/.tools-env
fi

if [[ ! -d ${NEW_TOOLS_DIR}/qemu ]]; then
    echo "Copying qemu folder to tools volume"
    sudo cp -r ${BASE_DIR}/tools/qemu ${NEW_TOOLS_DIR}/

    sudo rm -rf ${NEW_TOOLS_DIR}/qemu/imgs ${NEW_TOOLS_DIR}/qemu/*.sh

    sudo echo -e 'export QEMU_INSTALL_DIR=${TOOLS_DIR}/qemu' >> ${NEW_TOOLS_DIR}/.tools-env
    sudo echo -e 'export QEMU=${QEMU_INSTALL_DIR}/bin/qemu-system-aarch64' >> ${NEW_TOOLS_DIR}/.tools-env
    sudo echo -e 'export PATH=$PATH:$QEMU_INSTALL_DIR/bin' >> ${NEW_TOOLS_DIR}/.tools-env
fi

if [[ ! -d ${WORKSPACE} ]]; then
    if [[ -z "${USER}" ]]; then
        USER=`whoami`
    fi

    echo "Creating workspace folder"
    sudo mkdir -p ${WORKSPACE}
    sudo chmod 0777 ${WORKSPACE}
    sudo chown $USER:$USER ${WORKSPACE}

    touch ${WORKSPACE}/.wsp-env
    chmod 0775 ${WORKSPACE}/.wsp-env
fi

if [[ ! -d ${WORKSPACE}/imgs ]]; then
    cp -r ${QEMU_IMGS_DIR} ${WORKSPACE}/

    echo -e 'export QEMU_IMGS_DIR=${WORKSPACE}/imgs' >> ${WORKSPACE}/.wsp-env
fi

if [[ ! -d ${WORKSPACE}/linux ]]; then
    echo "Copying linux folder"

    OLD_RAMDISK_FILE_PATH=`grep "RAMDISK_FILE_PATH" ~/.bashrc`

    echo -e 'export LINUX_DIR=${WORKSPACE}/linux' >> ${WORKSPACE}/.wsp-env
    BUSYBOX_PATH=`echo ${OLD_RAMDISK_FILE_PATH} | sed -re 's/.+(busybox.*$)/\$LINUX_DIR\/\1/'`
    echo -e "export RAMDISK_FILE_PATH=$BUSYBOX_PATH" >> ${WORKSPACE}/.wsp-env

    cp -r ${LINUX_DIR} ${WORKSPACE}/

    echo "Done copying linux files"
fi

if [[ -d ~/share/docker-share/crosvm ]]; then
    mv ~/share/docker-share/crosvm ${WORKSPACE}/
    echo "Found crosvm, moved into workspace folder"
    mv ${WORKSPACE}/crosvm/crosvm ${WORKSPACE}/crosvm/crosvm-src
    cp ${WORKSPACE}/crosvm/crosvm-src/crosvm  ${WORKSPACE}/crosvm/crosvm
    rm -rf ${WORKSPACE}/crosvm/crosvm-src
    echo -e 'export CROSVM_FILE_PATH=${WORKSPACE}/crosvm/crosvm' >> ${WORKSPACE}/.wsp-env
fi

if [[ -d ~/share/docker-share/rootfs ]]; then
    mv ~/share/docker-share/rootfs ${WORKSPACE}/
    rm -rf ${WORKSPACE}/rootfs/oe-rpb
    echo "Moved rootfs to workspace folder"
    echo -e 'export VIRTIO_DEVICE_FILE=${WORKSPACE}/rootfs/rootfs-extfs-disk.img' >> ${WORKSPACE}/.wsp-env
fi

echo "Successfully populated the volumes with data from previous docker image"
echo "Exiting the old docker image"
