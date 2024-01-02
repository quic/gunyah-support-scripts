#!/bin/bash

# © 2023 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

set -e

if [[ ! -d ./crosvm-src ]]; then
    echo "Local sources copy doesn't exist, cloning now"
    git clone --recurse-submodules https://chromium.googlesource.com/crosvm/crosvm crosvm-src
else
    echo "crosvm sources already exists, skipping cloning"
fi
