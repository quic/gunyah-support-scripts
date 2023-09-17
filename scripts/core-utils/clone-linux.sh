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

echo -e "\nLINUX_DIR : ${LINUX_DIR}"

mkdir -p ${LINUX_DIR}/src
cd ${LINUX_DIR}/src

# LINUX
LINUX_VER="v6.5"
echo -e "\nCloning Linux ${LINUX_VER}:"
git clone \
    --depth=1 --progress -c advice.detachedHead=false \
    -b ${LINUX_VER}  \
    https://github.com/torvalds/linux.git   || {
	echo "Unable to clone Linux"
	exit 1
    }

# Enable Gunyah drivers in linux, static linking for now
echo "Applying gunyah drivers patch to linux"

# Install functional b4 first
# Instructions from https://b4.docs.kernel.org/en/latest/installing.html
echo "Installing b4 to download patches"

# Set git global config for b4 to work
git config --global user.email "$USER@test.com"
git config --global user.name "$USER"
git config --global color.ui auto

# Now get b4 installed to local folder
mkdir -p ${LINUX_DIR}/tools
cd ${LINUX_DIR}/tools
git clone https://git.kernel.org/pub/scm/utils/b4/b4.git b4
cd b4
git switch stable-0.9.y
git submodule update --init
pip install -r requirements.txt

echo "Installed b4 to ${LINUX_DIR}/tools/b4"

cd ${LINUX_DIR}/src/linux

${LINUX_DIR}/tools/b4/b4.sh shazam https://lore.kernel.org/all/20230613172054.3959700-1-quic_eberman@quicinc.com/
echo "Applied gunyah drivers patch successfully"

echo "Generate gunyah.config"
echo "CONFIG_VIRT_DRIVERS=y" > ./arch/arm64/configs/gunyah.config
echo "CONFIG_GUNYAH=y" >> ./arch/arm64/configs/gunyah.config
echo "CONFIG_GUNYAH_VCPU=y" >> ./arch/arm64/configs/gunyah.config
echo "CONFIG_GUNYAH_IRQFD=y" >> ./arch/arm64/configs/gunyah.config
echo "CONFIG_GUNYAH_IOEVENTFD=y" >> ./arch/arm64/configs/gunyah.config
echo "Created gunyah.config"

cd ${LINUX_DIR}

# RAMDISK
echo -e "\nDownloading Busybox:"
wget -c https://busybox.net/downloads/busybox-1.33.0.tar.bz2  || {
	echo "Unable to Download busybox"
	exit 1
    }

tar xf busybox-1.33.0.tar.bz2   || {
	echo "Unable to Uncompress busybox"
	exit 1
    }
