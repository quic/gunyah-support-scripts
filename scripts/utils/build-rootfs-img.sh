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
#     initramfs-*rootfs.ext4.gz : Stock linaro rootfs extfs image used as base
#     libgcc_s.so.1 : dependency for crosvm, built using bitbake from Open
#                     Embedded rpb image.
#                     This could use some optimization to just build one image
#                     instead of the whole package
# ----------------------------------------------------------------------------

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
# Linaro stock rootfs image

echo "Now preparing Linaro stock rootfs image"

ROOTFS_LINARO_STOCK="${ROOTFS_BASE}/linaro-stock"
LINARO_ROOTFS_IMAGE_FILE_NAME=initramfs-tiny-image-qemuarm64-20230321073831-1379.rootfs.ext4
LINARO_ROOTFS_IMAGE=${LINARO_ROOTFS_IMAGE_FILE_NAME}.gz
LINARO_ROOTFS_URL=https://snapshots.linaro.org/member-builds/qcomlt/testimages/arm64/1379

if [[ -d ${ROOTFS_REFERENCE_DIR}/etc/systemd/system ]]; then
	echo "Reference folder already exists in ${ROOTFS_REFERENCE_DIR}"
else
	mkdir -p ${ROOTFS_LINARO_STOCK}

	cd ${ROOTFS_LINARO_STOCK}

	echo "Now downloading Linaro reference rootfs image"

	# Download the rootfs image $LINARO_ROOTFS_IMAGE from linaro website
	if [[ ! -f  ${ROOTFS_LINARO_STOCK}/${LINARO_ROOTFS_IMAGE_FILE_NAME} ]]; then
		wget ${LINARO_ROOTFS_URL}/${LINARO_ROOTFS_IMAGE}

		echo "Download completed, decompressing the image"

		# Decompress the image LINARO_ROOTFS_IMAGE as LINARO_ROOTFS_IMAGE_FILE_NAME
		gunzip ${LINARO_ROOTFS_IMAGE}
	fi

	# It would be nice if resize works, but newer e2fsck is needed TBD later!!
	#resize2fs initramfs-tiny-image-qemuarm64-20230321073831-1379.rootfs.ext4 512M
	#e2fsck -f initramfs-tiny-image-qemuarm64-20230321073831-1379.rootfs.ext4

	echo "Decompression completed, mount the image to ${ROOTFS_LINARO_STOCK}/mnt"

	mkdir -p ${ROOTFS_LINARO_STOCK}/mnt

	# mount the Linaro stock rootfs image to extract all the files
	sudo mount -o loop ${LINARO_ROOTFS_IMAGE_FILE_NAME}  ${ROOTFS_LINARO_STOCK}/mnt

	echo "Copy the file tree to reference tree"

	sudo cp -r -v -p ${ROOTFS_LINARO_STOCK}/mnt/*   ${ROOTFS_REFERENCE_DIR}

	sudo umount ${ROOTFS_LINARO_STOCK}/mnt

	# Retain if needed later
	#rm -rf ${ROOTFS_LINARO_STOCK}
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
	echo -e '--initrd /usr/gunyah/initrd.img  --no-balloon --no-rng \\' >> ./svm.sh
	echo -e '--params "rw root=/dev/ram rdinit=/sbin/init earlyprintk=serial panic=0" \\' >> ./svm.sh
	echo -e ' /usr/gunyah/Image $@\n' >> ./svm.sh

	sudo cp ./svm.sh ${SVM_DESTINATION}
	rm -f ./svm.sh
	sudo chmod 0775 ${SVM_DESTINATION}/svm.sh
fi

echo "Completed copying crosvm and SVM kernel files to rootfs reference tree"


# ----------------------------------------------------------------------------
# Generate and copy libgcc_s.so.1 file

# crosvm has dependency on libgcc_s.so.1 file. For now a very long approach is
# taken to generate this file, but we can optimize this step later to use the
# required recipe only to generate this binary

# Following Reference commands are derived from files fetch.log, build.log at
# https://snapshots.linaro.org/member-builds/qcomlt/testimages/arm64/1379/

if [[ ! -f ${ROOTFS_REFERENCE_DIR}/lib/libgcc_s.so.1 ]]; then
	if [[ ! -f ~/bin/repo ]]; then
		echo "Installing repo into local bin folder"
		mkdir -p ~/bin
		#export PATH=~/bin:$PATH
		#echo "$PATH"
		curl http://commondatastorage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
		chmod a+x ~/bin/repo
	fi

	if [[ ! -f ~/.gitconfig ]]; then
		echo "Warning: setting the git global config to default values..!!"
		git config --global user.name "$USER"
		git config --global user.email "$USER@local.com"
		git config --global color.ui auto
	fi

	ROOTFS_IMAGE_TO_BUILD="rpb-console-image"
	export MACHINE=qemuarm64
	export DISTRO=rpb

	mkdir ${ROOTFS_BASE}/oe-rpb
	cd ${ROOTFS_BASE}/oe-rpb

	# fetch
	~/bin/repo init -u https://github.com/96boards/oe-rpb-manifest.git -b qcom/master
	~/bin/repo sync

	# add config for libgcc and other virtualization options
	echo -e "\n" > ./extra_local.conf
	echo "INHERIT += 'buildstats buildstats-summary'" >> ./extra_local.conf
	echo "PREFERRED_PROVIDER_virtual/kernel = 'linux-dummy'" >> ./extra_local.conf
	echo "PREFERRED_PROVIDER_android-tools-conf = 'android-tools-conf-configfs'" >> ./extra_local.conf
	echo "CORE_IMAGE_EXTRA_INSTALL += 'openssh libgcc'" >> ./extra_local.conf
	echo "PACKAGE_INSTALL:append = ' openssh libgcc'" >> ./extra_local.conf
	echo "DISTRO_FEATURES:append = ' virtualization'" >> ./extra_local.conf
	echo -e "\n" >> ./extra_local.conf

	echo -e "\n\n" > ./bblayers.conf


	source setup-environment build

	cat ../extra_local.conf >> conf/local.conf
	cat ../bblayers.conf >> conf/bblayers.conf

	echo '"Dumping local.conf.."'
	cat conf/local.conf

	bitbake -e > bitbake-environment

	bitbake ${ROOTFS_IMAGE_TO_BUILD}

	# Completed the build. The file libgcc_s.so.1 should be available at path
	# ${ROOTFS_BASE}/oe-rpb/build/tmp-rpb-glibc/sysroots-components/cortexa57/libgcc/usr/lib/libgcc_s.so.1
	LIBGCC_OUT_PATH="build/tmp-rpb-glibc/sysroots-components/cortexa57/libgcc/usr/lib"

	sudo cp ${ROOTFS_BASE}/oe-rpb/${LIBGCC_OUT_PATH}/libgcc_s.so.1 ${ROOTFS_REFERENCE_DIR}/lib
	sudo chmod 0755 ${ROOTFS_REFERENCE_DIR}/lib/libgcc_s.so.1

	rm -rf ${ROOTFS_BASE}/oe-rpb
fi

echo "Successfully created the reference files folder for rootfs image at : `pwd`"

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
