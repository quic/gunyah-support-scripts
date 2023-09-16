#!/bin/bash

# © 2022 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

set -e

if [[ -z "$DOCKER_TAG" ]]; then
    DOCKER_TAG=" hyp:dev-term "
fi

docker exec -it `docker ps | grep "${DOCKER_TAG}" | cut -d ' ' -f 1` /bin/bash

