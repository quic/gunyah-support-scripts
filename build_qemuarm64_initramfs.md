# Build qemuarm64 initramfs
## Build
To build qemuarm64 initramfs image, we should clone Yocto **poky** and **meta-qcom** .  
The method as follows:  

```bash
mkdir initramfs-tiny-image
cd initramfs-tiny-image/

git clone https://git.yoctoproject.org/poky
cd poky
git switch styhead 

git clone https://git.yoctoproject.org/meta-qcom
cd meta-qcom
git switch styhead

cd ..
source oe-init-build-env build-qemuarm64
# then will auto-change dir to build-qemuarm64

vim conf/bblayers.conf
# In BBLAYERS add meta-qcom with path

vim conf/local.conf
# Change MACHINE val to qemuarm64
# Add: INIT_MANAGER = "systemd"

bitbake initramfs-tiny-image
```

## Convert the image
After `bitbake` build successfully, we get `initramfs-tiny-image-qemuarm64.cpio.gz` . It is not EXT4 image, which is needed by **gunyah-support-scripts**.  
It is neccessary to convert this image:  

```bash
#!/bin/bash

CPIO_GZ_FILE="initramfs-tiny-image-qemuarm64.cpio.gz"
EXTRACT_DIR="rootfs_temp"
EXT4_IMAGE="rootfs_ext4.img"
EXT4_SIZE_MB="512"  # image size in MB

echo "Step 1: Extracting ${CPIO_GZ_FILE}..."
mkdir -p ${EXTRACT_DIR}
gzip -d -c -k ${CPIO_GZ_FILE} | (cd ${EXTRACT_DIR} && cpio -idm) 

echo "Step 2: Creating empty ${EXT4_IMAGE} file..."
dd if=/dev/zero of=${EXT4_IMAGE} bs=1M count=${EXT4_SIZE_MB} status=progress
mkfs.ext4 -F ${EXT4_IMAGE}

echo "Step 3: Copying contents into ${EXT4_IMAGE}..."
MOUNT_DIR="mnt_ext4"
mkdir -p ${MOUNT_DIR}
sudo mount -o loop ${EXT4_IMAGE} ${MOUNT_DIR}
sudo cp -a ${EXTRACT_DIR}/* ${MOUNT_DIR}/
sudo chown -R root:root ${MOUNT_DIR}
sudo umount ${MOUNT_DIR}
rmdir ${MOUNT_DIR}

echo "Step 4: Cleaning up and compressing..."
rm -rf ${EXTRACT_DIR}
gzip -k -f ${EXT4_IMAGE}

echo "Conversion complete. Your ext4.gz image is: ${EXT4_IMAGE}.gz"
```

## Use the image
Copy the `rootfs_ext4.img.gz` to Docker container, such as:  

```bash
cp <your_yocto_build_dir>/rootfs_ext4.img.gz ~/work/Gunyah/share/

cd <your_gunyah_support_scripts_dir>
export HOST_TO_DOCKER_SHARED_DIR=~/work/Gunyah/share
./scripts/run-docker.sh

# Get in docker container, exec:
cp ~/share/rootfs_ext4.img.gz ~/mnt/workspace/

# exit docker container
```

Then, while run `build-docker-img.sh`, it will ask:  
```
Do you want to provide a local rootfs image file? (y/n)
```
Answer **y**, and input the image path in your docker container, such as: `/home/<your_name>/mnt/workspace/rootfs_ext4.img.gz` 

Now, qemuarm64 initramfs image is ready for you.
