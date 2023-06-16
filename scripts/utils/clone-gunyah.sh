#!/bin/bash

# © 2022 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

set -e

if [[ -z "${REPO_URL}" ]]; then
    REPO_URL="https://github.com/quic"
fi

echo -e "\nCloning from repo : ${REPO_URL}\n" 

git clone ${REPO_URL}/gunyah-hypervisor.git hyp
echo ""

git clone ${REPO_URL}/gunyah-resource-manager.git resource-manager
echo ""

git clone ${REPO_URL}/gunyah-c-runtime.git musl-c-runtime
echo ""
