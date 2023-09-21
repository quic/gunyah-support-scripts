# Demo - Linux Booting in a SVM

To verify Linux booting in SVM, we need the following components:

- SVM components (in guest VM)
    - Linux kernel
    - RAM Disk image
    - Device tree

- HOST HLOS components
    - Linux kernel with Gunyah Hypervisor linux drivers
    - crosvm user space app as VMM
    - rootfs disk image containing all host related tools and SVM image files

Following sections describe how to generate these and test SVM functionality.

## SVM components (in guest VM)
### Linux kernel
The linux kernel image generated during docker build process to test qemu/aarch64 functionality should work for this purpose.
### RAM Disk image
The RAM Disk image (based on busybox) generated during docker build process to test qemu/aarch64 functionality should work here as well.
### Device tree
Device tree will be generated by crosvm (VMM) running in Host HLOS (PVM) based on the command line arguments passed while launching it. Resource Manager will patch the DT before its passed on to the SVM Linux kernel.

## HOST HLOS components
### Linux kernel with Gunyah Hypervisor linux drivers
The linux kernel image generated during docker build process already patches the linux kernel sources with Gunyah hypervisor linux drivers. These details can be examined in the provided script ```clone-linux.sh``` which is used to build linux image.enables to test qemu/aarch64 functionality should work for this

### crosvm user space app as VMM
A VMM is required to interact with Gunyah hypervisor to create, configure and launch the SVM and execute any OS in it. For the demo, ```crosvm``` user space app is built to handle this task. The details can be found in the included scripts  ```clone-crosvm.sh``` and ```build-crosvm.sh```.

Since crosvm sources and build can be really huge, these can be built later on the shared folder instead of building as part of the docker image. Once the crosvm executable is built, it will be included in the rootfs disk image which will be built later.

All the following instructions provided to be executed in the docker session.

Change dir to shared folder, so that we use host storage than using docker storage which will lose all the files on exit. This will also provide an opportunity to change the app to try.
```bash
mkdir ~/share/docker-share
```

Clone crosvm

```bash
cd ~/share/docker-share
~/utils/clone-crosvm.sh
```

Build crosvm.

```bash
cd crosvm
~/utils/build-crosvm.sh
```

> NOTE: Either a newer version of the Docker or a newer ubuntu distro (22.04 and later) has been encountering the following error..!! Observation was that the build works on host machine but doesn't in docker environment or vice versa. Currently we do not have a workaround for this problem, but if an older version of ubuntu distro (20.04) is available should work fine.

```
Trying to pull gcr.io/crosvm-infra/crosvm_dev:r0040...
Error: parsing image configuration: Get "https://storage.googleapis.com/artifacts.crosvm-infra.appspot.com/containers/images/sha256:6b0c28f5c282c677cc50a927e2227e5d89209ae3c6fa15db10593f7837a644fb": x509: certificate signed by unknown authority
```


This should result into crosvm executable app output in the crosvm root folder, add the file path to the environment variable

```bash
ls -la ~/share/docker-share/crosvm/crosvm
export CROSVM_FILE_PATH=~/share/docker-share/crosvm/crosvm
```

Crosvm generated here will have a dependency on libgcc_s.so.1, which will be generated later during the rootfs disk image generation.

### rootfs disk image containing all host related tools and SVM image files

Since the SVM linux kernel/ramdisk images and other host HLOS components need significant amount of storage space, we cannot just use ramdisk for host HLOS running in PVM. Instead we have to prepare the extfs formatted rootfs disk image that can be mounted as virtio disk. This method will provide the storage space for host HLOS without consuming the valuable RAM space.

Since generation of rootfs image also consumes huge space to generate, we can use the host shared space for this as well.

At a high level, this process does the following:
- Downloads the stock linaro rootfs extfs disk image (tiny initramfs to keep the size small)
- Downloads the Linaro OpenEmbedded Reference Platform Build (OE RPB) repo and generates the disk image
    - This step is taken only for the purpose of getting libgcc_s.so.1 file which is dependency for crosvm
    - This step takes significant amount of time
    - A potential optimization to avoid this huge build burden is a TODO later, but provides a potential if any useful components from this build can be utilized
- Prepare an empty extfs disk image of required size
- Copy all the required files into the rootfs extfs disk image
    - File tree from stock Linaro rootfs
    - All kernel .ko files from the kernel build
    - crosvm (VMM)
    - ramdisk, kernel image (for SVM)

The following instructions should be executed in the docker environment.

cd to shared folder

```bash
cd ~/share/docker-share
```

Start rootfs build process, this will ask for ```sudo``` password since the ```mount``` command used needs root access, provide the password created during the docker build process (default ```sudo``` password was set to ```1234```, unless its changed)
```bash
~/utils/build-rootfs-img.sh
```
After above step, all the required files tree would have been prepared for rootfs extfs disk image at the path ```~/share/docker-share/rootfs/reference```. If any additional files need to be copied to be accessible in the host HLOS PVM environment, this would be the time to do it.

After the reference disk file tree is ready, make a note of the size of the disk required using command ```du```, the last entry for the root folder provides the sizes of existing files in KB.

```bash
cd ~/share/docker-share/rootfs
du reference
```

Following entry shows its around 645 MB, adding some free space would be good, so we will consider making disk size as 800 MB.
```bash
645444  reference/
```

Now run the following script to generate the rootfs extfs disk image from the reference folder. Argument to -f should be absolute path. Again provide ```sudo``` password when asked for the ```mount``` command to work.

```bash
cd ~/share/docker-share/rootfs
~/utils/bldextfs.sh -f ~/share/docker-share/rootfs/reference -o ./rootfs-extfs-disk.img -s 800M
```

Make sure the unmount command succeeded (use ```df``` command to see that there are no mount point for ```./tmp-ext-fs```) and the file ```rootfs-extfs-disk.img``` is present.

Set the environment variable to provide it to qemu to map.

```bash
export VIRTIO_DEVICE_FILE=~/share/docker-share/rootfs/rootfs-extfs-disk.img
```

Now all the components needed to test linux running in SVM are ready. Run the qemu now with the following commands, note that dtb need to be generated again.

Note that the rootfs disk image is mounted RW, so any changes made will be persistent from HLOS running in PVM. So even the command history or any changes to .rc files would be available. But then it also means if the image gets corrupted it needs to be re-generated. So, if the image is in a state where it could be used as template, then keep a backup copy.

```bash
cd ~/tools/qemu
./run-qemu.sh dtb
```
After dtb is generated, run the command to launch qemu

```bash
./run-qemu.sh
```
This should result into booting to much complete linux environment in PVM via systemd init. Ignore the errors shown (unless those are fatal errors or crashes), if things went well, then a login prompt and a shell prompt should be seen

```bash
.
.
[  OK  ] Started User Login Management.
[  OK  ] Reached target Multi-User System.
         Starting Record Runlevel Change in UTMP...

Reference-Platform-Build-X11 3.0+linaro qemuarm64 ttyAMA0

qemuarm64 login: root (automatic login)
.
.
root@qemuarm64:~#
```

Once on the prompt, verify if the hypervisor related nodes showup

```bash
cd /sys/firmware/devicetree/base/hypervisor
find .
```

Now launch crosvm using the following command to create a SVM and run Linux OS in it. A shell script has been provided at ```/usr/gunyah/svm.sh``` to make it easier to launch.

```bash
/usr/gunyah/crosvm --no-syslog run --disable-sandbox \
--serial=type=stdout,hardware=virtio-console,console,stdin,num=1 \
--serial=type=stdout,hardware=serial,earlycon,num=1 \
--initrd /usr/gunyah/initrd.img  --no-balloon --no-rng \
--params "rw root=/dev/ram rdinit=/sbin/init earlyprintk=serial panic=0" \
/usr/gunyah/Image
```

OR

```bash
/usr/gunyah/svm.sh
```

The following shows the console logs of SVM. This could be pretty slow since each uart IO is going through the crosvm virtio-console (ie the control needs to switch from SVM back to PVM crosvm app to output the char to the actual console).

```bash
root@qemuarm64:~# /usr/gunyah/crosvm --no-syslog run --disable-sandbox --serial=type=stdout,hardware=virtio-console,console,stdin,num=1
--serial=type=stdout,hardware=serial,earlycon,num=1 --initrd /usr/gunyah/initrd.img  --no-balloon --no-rng --params "rw root=/dev/ram rd
init=/sbin/init earlyprintk=serial panic=0" /usr/gunyah/Image
[2023-09-15T21:44:00.904189296+00:00 INFO  crosvm] crosvm started.
[2023-09-15T21:44:00.935025408+00:00 INFO  crosvm] CLI arguments parsed.
[HYP] Emulated RAZ for ID register: ISS 0x36002f
[    0.000000] Booting Linux on physical CPU 0x0000000000 [0x000f0480]
[    0.000000] Linux version 6.5.0-00025-gd9af2a6a5a22 (yvasi@buildkitsandbox) (clang version 15.0.7 (https://github.com/llvm/llvm-project.git 8dfdcc7b7bf66834a761bd8de445840ef68e4d1a), LLD 15.0.7) #1 SMP PREEMPT Fri Sep 15 10:13:26 PDT 2023
[    0.000000] KASLR enabled
[    0.000000] random: crng init done
[    0.000000] Machine model: linux,dummy-virt
[    0.000000] earlycon: uart8250 at MMIO 0x00000000000003f8 (options '')
[    0.000000] printk: bootconsole [uart8250] enabled
[    0.000000] efi: UEFI not found.
[    0.000000] NUMA: No NUMA configuration found
[    0.000000] NUMA: Faking a node at [mem 0x0000000080000000-0x000000008fffffff]
[    0.000000] NUMA: NODE_DATA [mem 0x8ff709c0-0x8ff72fff]
[    0.000000] Zone ranges:

```
This script ```svm.sh``` can take additional arguments and pass on to ```crosvm``` app. As an example, we can provide the number of cpu's as additional argument to create SVM with more CPU cores. Note that adding more cores to SVM linux session might make console logs even slower..!!

```bash
/usr/gunyah/svm.sh --cpus 4
```

This should show that the Linux kernel is running in the SVM. Once verification of this linux environment is complete, issue ```poweroff``` command in the SVM linux shell to go back into the PVM linux environment. SVM can be launched again to verify a different configuration.

```bash
/ # poweroff
/ # umount: can't unmount /: Invalid argument
swapoff: can't open '/etc/fstab': No such file or directory
The system is going down NOW!
Sent SIGTERM to all processes
Sent SIGKILL to all processes
Requesting system poweroff
[ 7204.608721] reboot: Power down
```
> Note: Current latset version of Gunyah freezes on second time launch after SVM power off. This is working fine in the original version of gunyah before the updates, SVM relaunch feature can be verified on that original version of Gunyah/RM sources.

Press ```ctrl-a and x``` to exit Qemu

Follow-up TODO's:

The following areas require work, any help on these is appreciated:
- Enable ```ssh_server``` in PVM Linux OS image, so that we can connect multiple ssh sessions and test multiple SVM sessions simultaneously.
- Fix poor performance of the SVM Linux console, for example using the Gunayh RM Console driver.