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

# See if we can migrate data from Old docker image if existing
./check-and-migrate.sh $cmd

VERSION_SCRIPT=$(dirname "${BASH_SOURCE[0]}")/version.sh
. ${VERSION_SCRIPT}

CURRENT_DOCKER_IMAGE_TAG=hyp-dev-term:${CURRENT_VER}

# Use public docker registry
REGISTRY_SERVER="ubuntu:22.04"

# For internal Qcom network, set the environment variable using
# LOCAL_DOCKER_REGISTRY=docker-registry-ro.qualcomm.com/library
# Use local registry if set
if [[ ! -z "${LOCAL_DOCKER_REGISTRY}" ]]; then
	REGISTRY_SERVER="${LOCAL_DOCKER_REGISTRY}/${REGISTRY_SERVER}"
	echo "Using local registry server as : ${LOCAL_DOCKER_REGISTRY}"
fi

echo "Registry server is set to ${REGISTRY_SERVER}"

if [[ -z "${USE_THIS_DOCKERFILE}" ]]; then
	USE_THIS_DOCKERFILE="dockerfile-hyp" ;
fi

echo "Building Docker file ${USE_THIS_DOCKERFILE}"

DOCKER_OPTIONS=" build . "

#DOCKER_OPTIONS+=" --progress=plain "

#  no-cache alleviates some install errors for not finding some packages
#DOCKER_OPTIONS+=" --no-cache "

# user environment related so the permissions will same as the host machine
DOCKER_OPTIONS+=" --build-arg UID=$(id -u) "
DOCKER_OPTIONS+=" --build-arg GID=$(id -g) "
DOCKER_OPTIONS+=" --build-arg USER=${USER} "
DOCKER_OPTIONS+=" --build-arg REGISTRY=${REGISTRY_SERVER} "
DOCKER_OPTIONS+=" --build-arg ENV_VER=${CURRENT_VER} "

# Dockerfile name
DOCKER_OPTIONS+="  -f ${USE_THIS_DOCKERFILE} "

# Docker image Tag
DOCKER_OPTIONS+="  -t $CURRENT_DOCKER_IMAGE_TAG"

# Build docker image
$cmd $DOCKER_OPTIONS $*

echo -e "\nBuilt or updated the docker image, now installing or configuring Core tools\n"

echo ""
echo "*********** Sudo password Note..!! *********************************"
echo ""
echo "  Following commands are executed within docker environment, so when a"
echo "  prompt for sudo password showsup, type 1234 which is the default password"
echo "  set when building the docker image (unless it was changed)"
echo ""
echo "********************************************************************"
echo ""

HOST_TO_DOCKER_SHARED_DIR="" . ./run-docker.sh /bin/bash -c 'sudo -E $BASE_DIR/share/install-core-tools.sh'

# Now install workspace images
HOST_TO_DOCKER_SHARED_DIR="" . ./run-docker.sh /bin/bash -c '$BASE_DIR/share/install-wsp-imgs.sh'

echo -e "Building docker image completed\n"
