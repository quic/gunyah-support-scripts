#!/bin/bash

# © 2023 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

set -e

# ----------------------------------------------------------------------------
#   This file fetches and builds the rootfs extfs image that can be mounted as
#   a virtio disk image to host VM in Qemu. It Re-uses the already built
#   binaries, downloads few from internet and builds them.
#
#   NOTE: Script uses sudo to mount the fs image to extract the files.
#
#   Use built images:
#     Image : From linux kernel build in docker container
#     initrd.img : RAM Disk image built in docker container
#     *.ko : Kernel object modules built in linux kernel in docker container
#
#   Download and build:
#     crosvm : User space VMM running Host HLOS
#     buildroot : Simple root filesystem based on buildroot
#     libgcc_s.so.1 : dependency for crosvm, built using bitbake from Open
#                     Embedded rpb image.
#                     This could use some optimization to just build one image
#                     instead of the whole package
# ----------------------------------------------------------------------------

readyn() {
	local prompt="${1}"
	local default="${2:-y}"
	local suffix="[y/n]"
	local reply

	default="${default,,}"
	[[ "$default" != "y" && "$default" != "n" ]] && default="y"
	suffix="${suffix^^$default}"

	while :; do
		read -r -p "$prompt $suffix " reply
		[[ -z "$reply" ]] && reply="$default"
		case "$reply" in
			y|Y)
				return 0
			;;
			n|N)
				return 1
			;;
		esac
	done
}

IN_ERROR="NO"

if [[ -z "${LINUX_DIR}" ]] || [[ ! -f "${LINUX_DIR}/build/arch/arm64/boot/Image" ]]; then
	echo "Linux build folder not set or kernel image not found in LINUX_DIR : ${LINUX_DIR}"
	IN_ERROR="YES"
fi

if [[ -z "${RAMDISK_FILE_PATH}" ]] || [[ ! -f "${RAMDISK_FILE_PATH}" ]]; then
	echo "Ramdisk file path is not set or not found RAMDISK_FILE_PATH : ${RAMDISK_FILE_PATH}"
	IN_ERROR="YES"
fi

if [[ -z ${CROSVM_FILE_PATH} ]] || [[ ! -f ${CROSVM_FILE_PATH} ]]; then
	echo "crosvm file path is not set or not found in CROSVM_FILE_PATH : ${CROSVM_FILE_PATH}"
	IN_ERROR="YES"
fi

if [[ -z ${WORKSPACE} ]]; then
	echo "workspace path is not set WORKSPACE : ${WORKSPACE}"
	IN_ERROR="YES"
fi

if [[ "$IN_ERROR" = "YES" ]]; then
	echo "Resolve above errors and run the script again"
	return
fi

ROOTFS_BASE="${WORKSPACE}/rootfs"
ROOTFS_REFERENCE_DIR="${ROOTFS_BASE}/reference"

mkdir -p ${ROOTFS_REFERENCE_DIR}
cd ${ROOTFS_BASE}

#
#  First prepare the folder structure in reference folder, then copy the whole
#  file tree into the created and mounted root fs. This provides an opportunity
#  to update anything else required in the reference folder
#


# ----------------------------------------------------------------------------
# rootfs image

echo "Now preparing buildroot rootfs image"

if [[ -d ${ROOTFS_REFERENCE_DIR}/bin/busybox ]]; then
	echo "Reference folder already exists in ${ROOTFS_REFERENCE_DIR}"
else
	BUILDROOT_DIR="${ROOTFS_BASE}/buildroot"
	BUILDROOT_DEFCONFIG="gunyah_pvm_defconfig"
	BUILDROOT_ROOTFS="${BUILDROOT_DIR}/output/images/rootfs.tar"

	if [[ ! -e "${BUILDROOT_ROOTFS}" ]]; then
		BUILDROOT_GIT=https://gitlab.com/buildroot.org/buildroot.git
		BUILDROOT_TAG=2025.11.1

		if [[ ! -e "${BUILDROOT_DIR}" ]]; then
			echo "Now checking out buildroot ${BUILDROOT_TAG}"
			git clone ${BUILDROOT_GIT} --depth=1 -b ${BUILDROOT_TAG} "${BUILDROOT_DIR}"
		fi

		if [[ ! -e "${BUILDROOT_DIR}/.config" ]]; then
			echo "Building ${BUILDROOT_DEFCONFIG}"
			cp "${BASE_DIR}/share/${BUILDROOT_DEFCONFIG}" "${BUILDROOT_DIR}/configs/"
			cd "${BUILDROOT_DIR}"
			make "${BUILDROOT_DEFCONFIG}"
		fi
	fi

	cd "${BUILDROOT_DIR}"

	if readyn "Run make menuconfig to make changes to the rootfs?" "n" ; then
		make menuconfig
	fi

	make

	echo "Copy the file tree to reference tree"
	sudo tar -xvpSf "${BUILDROOT_ROOTFS}" -C "${ROOTFS_REFERENCE_DIR}"

	# Retain if needed later
	# rm -rf "${BUILDROOT_DIR}"
fi

# ----------------------------------------------------------------------------
# Linux kernel built modules
#
# Copy the linux build generated .ko files into the release folder
#  ./lib/modules/6.3.0-rc1-00035-g937b9453a2f3-dirty/kernel/
UTS_RELEASE=`cat ${LINUX_DIR}/build/include/config/kernel.release`
KO_FILES_DST="${ROOTFS_REFERENCE_DIR}/lib/modules/${UTS_RELEASE}/kernel"

if [[ -d ${KO_FILES_DST} ]]; then
	echo "Kernel files already copied to reference destination"
else
	echo "Copying the linux ko files to destination dir ${KO_FILES_DST}"
	cd ${LINUX_DIR}/build

	for f in $(find . -iname "*.ko");
	do
		DST_DIR=$(dirname "${KO_FILES_DST}/$f")
		#echo "mkdir ${DST_DIR}"
		sudo mkdir -p ${DST_DIR}
		sudo cp -v -p $f ${DST_DIR}
	done

	echo "Done copying linux kernel object files to reference rootfs tree"
fi
cd ${ROOTFS_BASE}

# ----------------------------------------------------------------------------
# crosvm and SVM related files

# Now copy the crosvm and SVM related files to destination
# these include, crosvm binary, SVM linux kernel image, ramdisk

SVM_DESTINATION=${ROOTFS_REFERENCE_DIR}/usr/gunyah

if [[ -f ${SVM_DESTINATION}/$(basename ${CROSVM_FILE_PATH}) ]]; then
	echo "Crosvm file is already copied to reference folder"
else
	sudo mkdir -p ${SVM_DESTINATION}
	if [[ ! -z ${CROSVM_FILE_PATH} ]] && [[ -f ${CROSVM_FILE_PATH} ]]; then
		echo "Copying crosvm file to rootfs reference tree"
		sudo cp -v -p ${CROSVM_FILE_PATH} ${SVM_DESTINATION}
	fi
fi

if [[ ! -f ${SVM_DESTINATION}/Image ]]; then
	sudo cp -v -p ${LINUX_DIR}/build/arch/arm64/boot/Image ${SVM_DESTINATION}
fi

if [[ ! -f ${SVM_DESTINATION}/$(basename ${RAMDISK_FILE_PATH}) ]]; then
	sudo cp -v -p ${RAMDISK_FILE_PATH} ${SVM_DESTINATION}
fi

if [[ ! -f ${SVM_DESTINATION}/svm.sh ]]; then
	echo -e '#!/bin/sh\n\n/usr/gunyah/crosvm --no-syslog run --disable-sandbox \\'  > ./svm.sh
	echo -e '--serial=type=stdout,hardware=virtio-console,console,stdin,num=1 \\' >> ./svm.sh
	echo -e '--serial=type=stdout,hardware=serial,earlycon,num=1 \\' >> ./svm.sh
	echo -e '--initrd /usr/gunyah/initrd.img --no-rng \\' >> ./svm.sh
	echo -e '--params "rw root=/dev/ram rdinit=/sbin/init earlyprintk=serial panic=0" \\' >> ./svm.sh
	echo -e ' /usr/gunyah/Image $@\n' >> ./svm.sh

	sudo cp ./svm.sh ${SVM_DESTINATION}
	rm -f ./svm.sh
	sudo chmod 0775 ${SVM_DESTINATION}/svm.sh
fi

echo "Completed copying crosvm and SVM kernel files to rootfs reference tree"

# -----------------------------------------------------------------------------
# Create a extfs device image of required size

if [[ -f ${WORKSPACE}/rootfs/rootfs-extfs-disk.img ]]; then
	echo "Rootfs image already exists, delete this file if need to create"
	echo "  new file with any modified content from reference folder"
else
	echo "Creating rootfs image file from reference : `pwd`"
	cd ${WORKSPACE}/rootfs
	. ~/utils/bldextfs.sh -f ${WORKSPACE}/rootfs/reference -o ${WORKSPACE}/rootfs/rootfs-extfs-disk.img -s 800M
fi
