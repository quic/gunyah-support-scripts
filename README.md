# Toolchain and support scripts

This repository stores scripts and Dockerfiles needed for building and testing Gunyah Hypervisor.

## Quick start:

- [Quick Setup instructions](quickstart.md)
- [Debug instructions and notes](debugging.md)

Gunyah related repositories:
- [Setup Tools and Scripts](https://github.com/quic/gunyah-support-scripts) (This repository)
- [Hypervisor](https://github.com/quic/gunyah-hypervisor.git) (Gunyah core hypervisor)
- [Resource Manager](https://github.com/quic/gunyah-resource-manager.git) (Platform policy engine)
- [C Runtime](https://github.com/quic/gunyah-c-runtime.git) (C runtime environment for Resource Manager)

> See https://github.com/quic/gunyah-hypervisor for additional documentation.

## Release notes

#### Dec 2023 (1.20)
- Moved all generated images out of docker image (folder re-arch)
- Using docker volumes for all generated images, so all changes will be persistent
- Faster and simpler updates to latest versions of scripts in future
- Added version info to file ```scripts/version.sh``` (previous releases are implied as 1.00 and 1.10)
    - Also set in env variable ```$ENV_VERSION``` in docker environment

#### Sep 2023
- Added scripts to generate all images required for SVM linux booting
- Updated instructions to demo SVM loading and execution

#### June 2023
- Major update from previous releases
- Simplified docker script
- Moved all commands into simple scripts
- Updated and simplified all instructions

## License

SPDX-License-Identifier: BSD-3-Clause

See [LICENSE](LICENSE) for the full license text.
