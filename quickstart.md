# Quick Start

Gunyah Hypervisor - Docker based development environment:

_The following configuration is tested_

- Linux machine (Ubuntu 20.04)
    - 8GB RAM
    - 40+ GB free disk space (for docker images)
    - Quick internet connection with sufficient quota (downloads 3-5+ GB)
- Docker (20.10)
    - [Installing Docker](https://docs.docker.com/engine/install/)
    - Note, version as reported by ```docker -v```
- LLVM (15.x) + musl C (1.1)
- QEMU (7.2)
- gdb-multiarch (9.2)

A Docker container environment containing the above tools is supported. The
scripts prepare an Ubuntu 22.04 based docker environment, download and build
LLVM, QEMU, a reference Linux kernel and Busybox ramdisk and a the Python
virtual environment to ease the development process.

A similar setup may be created without Docker directly on an Ubuntu 22.04
machine, however this has not been tested.

--------

All the required scripts are available at
[Gunyah support scripts](https://github.com/quic/gunyah-support-scripts). Clone
the files to any local folder on the host machine:

These commands are exected in the host machine terminal
```bash
mkdir -p ~/gunyah
cd ~/gunyah
git clone https://github.com/quic/gunyah-support-scripts
```

Scripts referenced from here on are located in the scripts folder of this repository.

--------

## Build the Docker image
### Note about updating from the previous versions
Latest versions of scripts (>= 1.20) have changed the folder layout compared to previous versions. The build script detects older images if present and migrate the images to latest version. Newer version scripts install all tools and images into docker volumes which are writable. So any modifications in those volumes to tools/images would persist, so any broken changes can be fixed by re-generating those tools/images. This new method helps to avoid time consuming process of download/build and storage space.

If the previous version of docker image was older than when SVM support was added (implied as 1.10 in [release notes](README.md#release-notes)), then its recommended that linux image be rebuilt in the latest package.

There are 2 volumes created ```tools-vol``` and ```wsp-vol```.

```tools-vol``` mounted at ```/usr/local/mnt/tools``` would contain llvm and qemu. LLVM toolchain typically don't need much updates but Qemu might need updates to add networking support in future.

```wsp-vol``` mounted in home folder at ```~/mnt/workspace``` will have all the rest of the images needed. These include linux, crosvm, rootfs etc.

Host folder is still mapped at ```~/share``` in order to share the gunyah hypervisor source/builds between docker and host environment so that it would be easy to handle edit/debugging code using tools on the host machine.

--------
### Some common pitfalls to avoid:

- Ensure _your userid_ is a member of the docker group (check with ```id```)
    + To add the group, run: ```sudo usermod -a -G docker $USER```, then logout and log back in.
- You may need to symlink /var/lib/docker to a filesystem with sufficient space (e.g. 40+ GB)
    + e.g. ```lrwxrwxrwx 1 root root 12 Jun  9 11:34 /var/lib/docker -> /home/docker```
- If the following errors are seen during Docker build:

    ```shell
    E: Failed to fetch,
    E: Unable to fetch some archives
    ```
     then uncomment the following option in the file ```dockerfile-hyp``` so that a fresh copy of the apt cache will be downloaded instead of using the stale ones.
     ```bash
     DOCKER_OPTIONS+=" --no-cache "
     ```

--------
### Building the Docker Image:

This method works for both upgrading from previous image as well as first time creation.

While building docker image do not set the environment variable ```HOST_TO_DOCKER_SHARED_DIR```, since the build operation will be executed from within the docker environment and it needs access to rest of the scripts which are mapped at the shared folder.

Change directory to ```gunyah-support-scripts/scripts```

Run the ```build-docker-img.sh``` script to generate the Docker image.

Since the tools are built within the docker environment, and when a password is asked for ```sudo``` password, in order to write to some folders and to execute some commands needs root access. So provide the password created during the docker build process (default ```sudo``` password was set to ```1234```, unless its changed)

During the build, Docker will download Ubuntu 22.04 packages, LLVM, QEMU, Linux
and other libraries and build them. _This process may take a few hours
depending on your internet connection system specs_.

Following commands are exected in the host machine terminal
```bash
cd ~/gunyah/gunyah-support-scripts/scripts
./build-docker-img.sh
```
If any errors occur, refer to above pitfalls and remedies. After this script completes successfully the docker image and other volumes are ready to be used.

--------

## Launch Docker environment

Launch the Docker container using the ```run-docker.sh``` script from the scripts folder.

A host machine folder can be shared with the docker environment. The
environment variable ```HOST_TO_DOCKER_SHARED_DIR``` can be set before running
the script or the script can be run from a folder that needs to be mapped from
host into the docker environment. If the variable is not set, then current folder is used to share. It is recommended to keep a known folder to share with docker and optionally set the above variable within ```.bashrc``` file so that every shell session started will have the variable set.

The choosen host folder is mounted in the docker container at
```~/share``` to facilitate copying files in or out of the container.
The environment variable ```HOST_SHARED_DIR``` can be set to change the shared folder mountpoint if desired.

Following commands are exected in the host machine terminal
```bash
export HOST_TO_DOCKER_SHARED_DIR=<shared folder path>
~/gunyah/gunyah-support-scripts/scripts/run-docker.sh
```
OR

```bash
mkdir -p ~/gunyah
cd ~/gunyah
~/gunyah/gunyah-support-scripts/scripts/run-docker.sh
```

Running this script starts a shell session in the docker container, in which all the
following development/testing processes can be performed. A set of scripts are provided to assist
building and running Gunyah based systems.

Note: `the Docker environment has ```sudo``` privileges for the user with the default password ```1234```. This was set in the docker-hyp when building the container.

--------

<h2>All the following commands are run within the docker container!</h>

## Test QEMU and Linux image

Firstly, it is useful to test that the built QEMU and Linux images work correctly, without Gunyah.

```bash
cd ~/mnt/workspace
kern-test.sh
```
Note: *It may take several seconds for Linux to boot on the simulator before any console output.*

Above script should boot linux kernel into a shell running in Qemu emulator. Within a couple of mins, all the linux log messages should show up. Press any key go into shell and test the linux environment.

Output:
```
[    0.000000] Booting Linux on physical CPU 0x0000000000 [0x000f0510]
[    0.000000] Linux version 6.2.0-rc7-g0983f6bf2bfc (nemo@9a231c81b3c5) (aarch64-linux-gnu-gcc (Ubuntu 9.4.0-1ubuntu1~20.04.1) 9.4.0, GNU ld (GNU Binutils for Ubuntu) 2.34) #1 SMP PREEMPT Wed Feb  8 14:39:22 PST 2023
[    0.000000] random: crng init done
[    0.000000] Machine model: linux,dummy-virt
[    0.000000] efi: UEFI not found.
[    0.000000] NUMA: No NUMA configuration found
[    0.000000] NUMA: Faking a node at [mem 0x0000000040000000-0x00000000bfffffff]
[    0.000000] NUMA: NODE_DATA [mem 0xbfbeca00-0xbfbeefff]
...
[   53.783957] uart-pl011 9000000.pl011: no DMA platform data
[   55.779296] Freeing unused kernel memory: 7936K
[   55.804200] Run /sbin/init as init process

Please press Enter to activate this console.
/ # ls
bin      etc      proc     sbin     usr
dev      linuxrc  root     sys
/ #
```

Note: Since QEMU is run interactively with ```-nographic```, the **CTRL-A**
escape key is required to interact with QEMU.

To exit QEMU: **CTRL-A** + ```x```

Note: the qemu run scripts can be modified to start ```qemu-system-aarch64```
to open a socket (for telnet) for the UART instead of running interactive on
the shell and/or open a separate monitor telnet session to interact with QEMU
and control/debug any resources.

--------

## Clone and build a Gunyah Hypervisor image

The Gunyah hypervisor sources can be cloned from the host machine or from within the docker environment to
the shared folder.

It is strongly recommended to keep sources on the host machine's filesystem,
since the sources and binary can be used on host to debug. But the builds need to be done within the docker environment only.

To clone the sources run the provided script

```bash
cd ~/share/gunyah
clone-gunyah.sh
```

This will clone the required source repositories into the following
directory structure. (All scripts assume these directory names)

```bash
(gunyah-venv) nemo@hyp-dev-env:~/share/gunyah$ ls
hyp  musl-c-runtime  resource-manager
```

This script may also be used to clone sources in the shared folder from your host machine.

--------

## Building a Gunyah Hypervisor image

The Gunyah image build requires the above three source repositories to have been cloned.

The build script *must be run from within the docker container*.

This example assumes that we are building the sources cloned in the shared folder
```~/share/gunyah``` as visible from the docker container.

To build the Gunyah image for the ```qemu``` target:

```bash
cd ~/share/gunyah
build-gunyah.sh qemu
```

Note: The docker container setup adds ```~/utils``` (containing build-gunyah.sh)
to the PATH.

When the build script completes successfully, it produces an output image
```<target>/hypvm.elf```. This is also copied to the path in the environment
variable ```QEMU_IMGS_DIR```, which has default path set to
```~/mnt/workspace/imgs```.

--------

## Test Hypervisor and Linux booting

The Gunyah image can now be run on the QEMU system simulator. The reference
mainline Linux kernel can be booted as a primary VM under the Gunyah
hypervisor.

First, we need to run QEMU to generate a devicetree binary used for booting with the hypervisor.

```bash
cd ~/mnt/workspace
run-qemu.sh dtb
```
We can now run QEMU with Gunyah and the Linux primary VM. This will boot with
the Gunyah Hypervisor and a single Linux VM. This should boot up with the same
Linux kernel, as run previously without Gunyah.

```bash
run-qemu.sh
```

This should produce output below:
```
(gunyah-venv) nemo@hyp-dev-env:~/mnt/workspace$ run-qemu.sh
[HYP] debug disabled
[HYP] No spectre-BHB mitigation registered for unknown core 0:2
[HYP] added heap: partition 0xffffffd60000a908, virt 0xffffffeeb0000000, phys 0xbdc00000, size 0x100000
[HYP] added heap: partition 0xffffffd600016b60, virt 0xffffff938c100000, phys 0xbdd00000, size 0x2300000
. . .
[    7.315612] uart-pl011 9000000.pl011: no DMA platform data
[    8.675942] Freeing unused kernel memory: 7936K
[    8.687593] Run /sbin/init as init process

Please press Enter to activate this console.
/ # ls
bin      etc      proc     sbin     usr
dev      linuxrc  root     sys
/ #
```

--------

## SVM booting Linux

This page describes how to prepare the host environment and the guest environment to showcase the capability of SVM booting Linux HLOS.

[Linux booting on SVM in Gunyah](svm_booting_linux.md)

--------

# Non-Docker setup

If for any reason a Docker environment is not preferred, a native host
environment can be prepared using the same scripts that were used to prepare the
docker environment (refer to the docker config file ```dockerfile-hyp```). Some
modifications may be required, your milage may vary.

Since this brings too many variations into the mix that could potentially break
the toolchain or other builds etc. in an unpredictable way, we are not
supporting this use case. It's included here for information purposes only.
