# © 2021 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

# Dockerfile for Gunyah Hypervisor on QEMU simulator

FROM ubuntu

# FIXME: The addresses below are hardcoded for the QEMU target.
ENV INITRD_BASE=0x44400000
ENV LINUX_BASE=0x41080000
ENV DT_BASE=0x44200000

RUN apt-get update && \
	apt-get -y upgrade

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Australia/Sydney

# Generic libraries
RUN apt-get install -y \
    software-properties-common \
    build-essential \
    tzdata \
    python3 \
    python-dev \
    python \
    python3-pip \
    sudo \
    git \
    make \
    gcc \
    g++ \
    ninja-build \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    cpio \
    device-tree-compiler \
    wget \
    lsb-release \
# QEMU dependencies
    libglib2.0-dev \
    libfdt-dev \
    libpixman-1-dev \
    zlib1g-dev \
# gdb 9.2 dependencies
    libreadline-dev \
    guile-2.0-dev \
    texinfo \
    libexpat1-dev \
    libmpfr-dev \
# Linux dependencies
    bc \
    libssl-dev \
    flex \
    bison \
# Toolchain dependencies
    libz3-dev \
    cmake \
# Repos dependencies
    python3-venv

# Install latest QEMU AArch64 Simulator
RUN cd /usr/local/src/ && \
	git clone https://git.qemu.org/git/qemu.git && \
	cd qemu && \
	git submodule init && \
	git submodule update --recursive && \
	./configure --target-list=aarch64-softmmu --enable-debug && \
	make

ENV PATH="/usr/local/src/qemu/build:$PATH"

# Install gdb 9.2 for debugging purposes
RUN cd /usr/local/src/ && \
	wget "https://ftp.gnu.org/gnu/gdb/gdb-9.2.tar.gz" && \
	tar -xvzf gdb-9.2.tar.gz && \
    rm -rf gdb-9.2.tar.gz && \
	cd gdb-9.2 && \
	mkdir build && \
	cd build && \
	../configure \
	--enable-targets=all \
	--prefix=/build \
	--enable-languages=all \
	--enable-multilib \
	--enable-interwork \
	--with-system-readline \
	--disable-nls \
	--with-python=python \
	--with-guile=guile-2.0 \
	--with-system-gdbinit=/etc/gdb/gdbinit && \
	make && \
	make install && \
	mv gdb/gdb /usr/bin/gdb-multiarch

# Create output directory
RUN cd /usr/local/src/ && \
	mkdir out
ENV OUTPUT_DIR=/usr/local/src/out

# Build the latest linux
RUN cd /usr/local/src/ && \
    git clone --depth=1 https://github.com/torvalds/linux.git && \
	cd linux/ && \
	make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig && \
	make -j4 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- && \
	cp ./arch/arm64/boot/Image.gz $OUTPUT_DIR/. && \
	cp ./arch/arm64/boot/Image $OUTPUT_DIR/.

# Compile a simple Busybox based ramdisk
# TODO: create a QEMU disk image for Linux primary VM to mount
RUN cd /usr/local/src/ && \
	wget -c https://busybox.net/downloads/busybox-1.33.0.tar.bz2 && \
	tar xf busybox-1.33.0.tar.bz2 && \
    rm -rf busybox-1.33.0.tar.bz2 && \
	cd busybox-1.33.0 && \
	make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- defconfig && \
	make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- menuconfig && \
    sed -i '/# CONFIG_STATIC is not set/c\CONFIG_STATIC=y' .config && \
	ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- make -j24 && \
	ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- make install && \
	cd _install/ && \
	mkdir proc sys dev etc etc/init.d && \
	echo "#!bin/sh" >> etc/init.d/rcS && \
	echo "mount -t proc none /proc" >> etc/init.d/rcS && \
	echo "mount -t sysfs none /sys" >> etc/init.d/rcS && \
	chmod u+x etc/init.d/rcS && \
	grep -v tty ../examples/inittab > ./etc/inittab && \
	find . | cpio -o -H newc | gzip > $OUTPUT_DIR/initrd.img

# Copy script to build llvm toolchain
COPY llvm_musl_build.sh $OUTPUT_DIR/.

# Build LLVM toolchain to compile hyp
RUN cd $OUTPUT_DIR/. && \
    ./llvm_musl_build.sh

ENV LLVM=$OUTPUT_DIR/llvm-musl-install

# Get the libfdt source code and cross compile it for AArch64
RUN cd /usr/local/src/. && \
    git clone https://github.com/dgibson/dtc.git && \
    cd dtc && \
    CC=aarch64-linux-gnu-gcc make install libfdt PREFIX=$OUTPUT_DIR/c-application-sysroot && \
    cd .. && \
    rm -rf dtc

ENV LOCAL_SYSROOT=$OUTPUT_DIR/c-application-sysroot

# Install the python dependencies
RUN cd $OUTPUT_DIR/. && \
    python3 -m venv gunyah-venv && \
    chmod a+x gunyah-venv/bin/activate && \
    . gunyah-venv/bin/activate && \
    pip3 install --upgrade pip && \
    pip3 install wheel && \
    git clone https://github.com/quic/gunyah-hypervisor.git && \
    pip3 install -r $OUTPUT_DIR/gunyah-hypervisor/tools/requirements.txt && \
    rm -rf gunyah-hypervisor

# Generate a dtb with 512M of RAM
RUN cd $OUTPUT_DIR && \
	qemu-system-aarch64 \
	-machine virt,virtualization=on,gic-version=3,highmem=off \
	-cpu max -m size=512M -smp cpus=8 -nographic \
	-kernel $OUTPUT_DIR/Image \
	-append "rw root=/dev/ram rdinit=/sbin/init earlyprintk=serial,ttyAMA0 console=ttyAMA0" \
	-machine dumpdtb=virt_qemu.dtb

# Create an overlay DT node with the created RAM disk size and apply it to the generated DT
RUN cd $OUTPUT_DIR/ && \
	export INITRD_SIZE=$(stat -Lc %s $OUTPUT_DIR/initrd.img) && \
	export INITRD_END=$(printf "0x%x" $((${INITRD_BASE} + ${INITRD_SIZE})) ) && \
	echo " \
	/dts-v1/; \
	/{ \
	fragment@0{ \
	target-path = \"/chosen\"; \
	 __overlay__{ \
	linux,initrd-start = <${INITRD_BASE}>; \
	linux,initrd-end = <${INITRD_END}>; \
	}; \
	}; \
	};" \
	> overlay.dts && \
	dtc -@  -I dts -O dtb overlay.dts -o overlay.dtbo && \
	fdtoverlay -v -i virt_qemu.dtb -o virt.dtb overlay.dtbo && \
	rm overlay.dts overlay.dtbo virt_qemu.dtb && \
	dtc -I dtb -O dts virt.dtb > virt.dts

# Create an executable to start QEMU with Gunyah and one Linux VM
RUN cd $OUTPUT_DIR && \
    echo "#!/bin/bash" >> start_cmd.sh && \
    echo "if [ \$# -eq 0 ]" >> start_cmd.sh && \
    echo "then" >> start_cmd.sh && \
    echo "echo Please supply hypvm.elf file" >> start_cmd.sh && \
    echo "exit 1" >> start_cmd.sh && \
    echo "fi" >> start_cmd.sh && \
    echo "qemu-system-aarch64 \\" >> start_cmd.sh &&\
	echo "-machine virt,virtualization=on,gic-version=3,highmem=off \\" >> start_cmd.sh &&\
	echo "-cpu max -m size=2G -smp cpus=8 -nographic \\" >> start_cmd.sh && \
	echo "-kernel \$1 \\" >> start_cmd.sh && \
	echo "-device loader,file=$OUTPUT_DIR/Image,addr=$LINUX_BASE \\" >> start_cmd.sh && \
	echo "-device loader,file=$OUTPUT_DIR/virt.dtb,addr=$DT_BASE \\" >> start_cmd.sh && \
	echo "-device loader,file=$OUTPUT_DIR/initrd.img,addr=$INITRD_BASE" >> start_cmd.sh && \
    chmod u+x start_cmd.sh
