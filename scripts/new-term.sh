#!/bin/bash

# © 2022 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

set -e

if [[ -f .dockr-env-rc ]]; then
	# Prevents new terminal attach from redoing everything
	mv .dockr-env-rc .dockr-env-rc-bak
fi

if [[ -z "$DOCKER_TAG" ]]; then
    DOCKER_TAG=" hyp:dev-term "
fi

docker exec -it `docker ps | grep "${DOCKER_TAG}" | cut -d ' ' -f 1` /bin/bash

if [[ -f .dockr-env-rc-bak ]]; then
	mv .dockr-env-rc-bak .dockr-env-rc
fi
