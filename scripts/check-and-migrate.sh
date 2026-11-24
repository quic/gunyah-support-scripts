#!/bin/bash

# © 2022 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

# This script is run from the host machine to execute in old docker image to
# migrate the data from previous docker image into volumes to be used in the
# newer version of docker image. This will save time and space rebuilding all
# the tools and images again (like llvm, qemu, linux etc)

RENAME_TAG=hyp-dev-term:1.10
OLD_TAG=hyp:dev-term
cmd=$1

OLD_TAG_ID=`$cmd images --format="{{.Repository}}:{{.Tag}} {{.ID}}" | grep "hyp:dev-term" | cut -d " " -f 2`
NEW_TAG_ID=`$cmd images --format="{{.Repository}}:{{.Tag}} {{.ID}}" | grep "hyp-dev-term" | cut -d " " -f 2`

# If old tag exists then extract the volumes and discard it
if [[ ! -z $OLD_TAG_ID ]]; then
    # Tag the old image to newer format
    $cmd image tag $OLD_TAG $RENAME_TAG

    # Remove old tag
    $cmd image rm $OLD_TAG
    echo "Renamed old tag to new format, now the tag for old image is $RENAME_TAG"

    echo ""
    echo "*********** Sudo password Note..!! *********************************"
    echo ""
    echo "  Following commands are executed within docker environment, so when a"
    echo "  prompt for sudo password showsup, type 1234 which is the default password"
    echo "  set when building the docker image (unless it was changed)"
    echo ""
    echo "********************************************************************"
    echo ""


    HOST_TO_DOCKER_SHARED_DIR="" DOCKER_TAG=$RENAME_TAG . ./run-docker.sh /bin/bash -c '$BASE_DIR/share/migrate-tools-to-vol.sh'

    echo "Old docker image can be removed *after* the new docker image has been verified to work"
    echo "Use the following command to remove stoped containers and delete the dangling images"
    echo ' docker rm $(docker ps -a -q) ; docker image rm hyp-dev-term:1.10 ; docker image prune '
fi
