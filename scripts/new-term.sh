#!/bin/bash

# © 2022 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

#set -e
cmd_p=$(which podman)
cmd_d=$(which docker)

if [ ! -z $cmd_p ]; then
	echo "Use podman ..."
	cmd=$cmd_p
elif [ ! -z $cmd_d ]; then
	echo "Use docker ..."
	cmd=$cmd_d
else
	echo "Error:Please install docker or podman firstly!"
	exit 1
fi

VERSION_SCRIPT=$(dirname "${BASH_SOURCE[0]}")/version.sh
. ${VERSION_SCRIPT}

if [[ -z "$DOCKER_TAG" ]]; then
    DOCKER_TAG=" hyp-dev-term:${CURRENT_VER} "
fi

$cmd exec -it `$cmd ps | grep "${DOCKER_TAG}" | cut -d ' ' -f 1` /bin/bash
