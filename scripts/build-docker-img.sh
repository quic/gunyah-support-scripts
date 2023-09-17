#!/bin/bash

# © 2022 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

set -e

# Use public docker registry
REGISTRY_SERVER="ubuntu:22.04"

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

# Dockerfile name
DOCKER_OPTIONS+="  -f ${USE_THIS_DOCKERFILE} "

# Docker image Tag
DOCKER_OPTIONS+="  -t hyp:dev-term"

# Build docker image
docker $DOCKER_OPTIONS $*
