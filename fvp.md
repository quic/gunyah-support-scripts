# Getting started with Arm FVP AEM

Gunyah supports the Arm Fixed Virtual Platform (FVP) Architecture Envelope
Model as `platform=fvp-aem`. This provides a native Linux host workflow for
building and booting the Gunyah hypervisor without QEMU or Docker.

The existing [Docker quickstart](quickstart.md) and support scripts provision
the QEMU environment. They do not install FVP or build its TF-A boot firmware.
Install the model and provide compatible boot inputs separately.

## Last validation

The native host workflow was last validated on November 13, 2026:

| Component | Version or revision used |
| --- | --- |
| Arm model | FVP Base RevC 2xAEMvA 11.30.27 (installation suffix `11.30_27`) |
| Hypervisor | `fce68f7ab`, `platform=fvp-aem`, `quality=debug` |
| Resource manager | `99880210d`, `platform=fvp-aem`, `quality=debug` |
| C runtime | `37daa784e`, `quality=debug` |
| LLVM | 22.1.0 (installed Snapdragon build) |
| Python | 3.10.12 |
| Device tree compiler | 1.6.1 |

The `gunyah-baseline` image booted Linux to a Buildroot login prompt with
eight CPUs activated. Linux reported running under Gunyah hypervisor 51/v1.
TF-A BL31, Linux, and the ramdisk were existing compatible images; all Gunyah
components and the Linux base device tree were built from open-source sources.

The `unittests` image also booted, but the complete suite failed its timer
lateness check. Linux logged an initramfs unpacking warning before reaching
login. These results establish basic Linux boot, rather than complete test
suite or device coverage. FVP inside Docker and the QEMU workflow's generated
Linux/BusyBox images have not been validated with these FVP instructions.

## Prepare the host

Install the `FVP_Base_RevC-2xAEMvA` executable and its host runtime dependencies
using the instructions for your Arm model distribution. Supply upstream LLVM
22.1.0 with an AArch64 C library, Ninja, Python virtual-environment support,
and `dtc`.

Keep the open-source repositories in sibling directories:

```text
gunyah/
    gunyah-support-scripts/
    hyp/
    resource-manager/
    musl-c-runtime/
    gunyah-app-sysroot/
```

The existing `scripts/utils/clone-gunyah.sh` clones `hyp`, `resource-manager`,
and `musl-c-runtime` into the current directory. It defaults to the public
`https://github.com/quic` repositories; check any inherited `REPO_URL` override
before using it. Use matching revisions with `fvp-aem` support and provide an
application sysroot containing the required AArch64 libraries and headers.
See `hyp/docs/setup.md` for toolchain and sysroot requirements.

From the hypervisor checkout, create a dedicated Python environment:

```sh
cd /path/to/gunyah/hyp
python3 -m venv build-fvp-venv
build-fvp-venv/bin/python -m pip install -r tools/requirements.txt
export LLVM=/path/to/llvm/22.1.0/
export LOCAL_SYSROOT=/path/to/gunyah/gunyah-app-sysroot
```

Keep source inputs and build outputs within the gunyah workspace. Use
explicit environment and image paths to avoid accidentally selecting another
Gunyah checkout's dependencies.

## Build and package

Use the hypervisor repository's FVP helper:

```sh
FEATURESET=gunyah-baseline,unittests bash tools/fvp_aem/build.sh
```

It builds all three gunyah components into `hyp/build-fvp/`, packages
the baseline image with the resource manager and C runtime, and converts the
boot images to flat binaries. `QUALITY` defaults to `debug`; `FEATURESET`
defaults to `gunyah-baseline`. The Linux base device tree is compiled from the
open-source resource manager's `platform/fvp/dts/fvp-aem-simple.dts`.

The support repo's `build-gunyah.sh` currently selects a featureset only for
QEMU. Follow the FVP helper above when building `fvp-aem`.
Rebuild and repackage after source changes before testing; running the model
alone reuses the existing boot binary.

## Boot the simulator

Provide a TF-A BL31 built for the model, with a non-secure entry point of
`0x88000000`. For Linux boot, also provide an AArch64 Linux `Image` and a
compatible initramfs. The runner recognizes a Buildroot welcome banner as
its Linux success condition; other root filesystems require a corresponding
completion check. Check the base device tree's initrd range against the
supplied ramdisk size.

```sh
FVP_MODEL=/path/to/FVP_Base_RevC-2xAEMvA
BL31=/path/to/arm-trusted-firmware/build/fvp/debug/bl31.bin
LINUX_IMAGE=/path/to/Linux/Image
RAMDISK=/path/to/Linux/ramdisk-buildroot.img

build-fvp-venv/bin/python tools/fvp_aem/run.py \
    --mode linux --model "$FVP_MODEL" --bl31 "$BL31" \
    --linux "$LINUX_IMAGE" --ramdisk "$RAMDISK"

build-fvp-venv/bin/python tools/fvp_aem/run.py \
    --mode unittests --model "$FVP_MODEL" --bl31 "$BL31"
```

These commands run from `hyp/`. The model runs headless with separate UART
logs under `build-fvp/logs/`; UART0 carries TF-A, UART1 the hypervisor/resource
manager, and UART2 Linux. Each run records the command and input hashes in
`inputs.json`. The runner stops its model process on completion, failure, or
timeout. The model still opens local UART sockets with GUI terminals disabled.

See `hyp/docs/fvp.md` for load addresses, output paths, and detailed validation
checks. Unit-test success requires all eight CPUs to complete; earlier
subsystem completion messages do not establish a full suite pass.

## Using an existing Docker environment

FVP is a supported hypervisor target, but the FVP container workflow remains
unvalidated. The Docker setup scripts continue to provision QEMU. They do not
download FVP or prepare TF-A for these instructions.

For a future container validation, make the model and its runtime dependencies
available inside the container, mount the gunyah repositories,
sysroot, and boot images, and use container-visible paths in the commands
above. The existing `run-docker.sh` supports a shared host directory through
`HOST_TO_DOCKER_SHARED_DIR` and additional Docker arguments through
`ADDITIONAL_DOCKER_ARGS`. Keep build outputs and logs on a writable mount.
The Docker build of upstream LLVM 22.1.0 and its generated Linux/BusyBox images
need separate FVP compatibility checks before this is presented as a tested
container workflow.
