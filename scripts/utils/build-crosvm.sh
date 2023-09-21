#!/bin/bash

# © 2023 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

set -e

./tools/dev_container sh -c "cargo build --features gunyah --target aarch64-unknown-linux-gnu --release --no-default-features && cp /scratch/cargo_target/aarch64-unknown-linux-gnu/release/crosvm ."
