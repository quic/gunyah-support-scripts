#!/bin/bash

# © 2023 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

set -e

if [[ ! -f ./crosvm ]]; then
    echo "Building crosvm from folder `pwd`"
    cd ./crosvm-src
	mount --make-shared /
    ./tools/dev_container sh -c "cargo build --features gunyah --target aarch64-unknown-linux-gnu --release --no-default-features && cp /scratch/cargo_target/aarch64-unknown-linux-gnu/release/crosvm ."

    echo "Completed building crosvm binary, copying to parent folder"
    cp ./crosvm ../
    cd ..

    # Delete sources to save on space
    rm -rf ./crosvm-src
else
    echo "Crosvm binary already exists, skipping building"
fi
