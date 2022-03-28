# Toolchain and support scripts

This repository stores scripts and Dockerfiles needed for building and testing Gunyah Hypervisor.

## Initialize the built environment

Building Gunyah requires [LLVM](https://llvm.org/) cross-compiler. `gunyah-environment.sh` will clone and install LLVM in `<path-to-install>` directory.

    gunyah-environment.sh --toolchain --install=<path-to-install>

For any dependencies such as `libfdt` and python virtual environment use `gunyah-environment.sh` with `--deps` option which create `<path-to-install>\hypervisor`.

    gunyah-environment.sh --deps --install=<path-to-install>

`gunyah-environment.sh` generates `<path-to-install>\hypervisor\source` which contains the necessary environment variable in order to run `gunyah-build.sh`. Run

    . <path-to-install>\hypervisor\source

Before using `gunyah-build.sh` to build Gunyah.

### Platforms

Currently the only supported platform is [QEMU](https://www.qemu.org/). To install the supported version of the QEMU run:

    gunyah-environment.sh --qemu --install=<path-to-install>

## Configure and build ''Gunyah''

To build Gunyah and all dependencies including [gunyah-resource-manager](https://github.com/quic/gunyah-resource-manager) and [gunyah-c-runtime](https://github.com/quic/gunyah-c-runtime) use `gunyah-build.sh`. Running

    gunyah-build.sh --platform=qemu --featureset=gunyah-rm-qemu --quality=debug

clone and build hypervisor, resource manager, and runtime. By default it uses `https://github.com/quic/` as remote address. Use `--remote` to override the default remote address.

There are three options to set repositories and branches: `--hypervisor`, `--c-runtime`, and `--resource-manager`. For example to set a different repository for hypervisor use `--hypervisor=gunyah-hypervisor.git,next` where `next` is the branch name.

## Example

To build latest version of Gunyah Run

    gunyah-environment.sh --toolchain --qemu --deps --install=<path-to-install>
    . <path-to-install>\hypervisor\source
    gunyah-build.sh --platform=qemu --featureset=gunyah-rm-qemu --quality=debug --hypervisor=gunyah-hypervisor.git,next --c-runtime=gunyah-c-runtime.git,next --resource-manager=gunyah-resource-manager.git,next

> See https://github.com/quic/gunyah-hypervisor for additional documentation.

## License

SPDX-License-Identifier: BSD-3-Clause

See [LICENSE](LICENSE) for the full license text.
