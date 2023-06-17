#!/bin/bash

# © 2022 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

set -e

# versions of the tools lark_parser, cheetah and pyelftools are listed
# in the requirements.txt file in the Gunyah hypervisor source repository
# in the path hyp/tools/requirements.txt

pushd ${TOOLS_DIR}

echo "Preparing python venv for gunyah"
python3 -m venv gunyah-venv &&
    chmod a+x gunyah-venv/bin/activate &&
    . gunyah-venv/bin/activate &&
    pip3 install --upgrade pip &&
    pip3 install wheel &&
    pip3 install lark_parser==0.8.9 &&
    pip3 install Cheetah3==3.2.6 &&
    pip3 install pyelftools==0.26 || {
    echo "Faild to setup python venv"
    # popd
    exit 1
}

popd
echo "source ${TOOLS_DIR}/gunyah-venv/bin/activate" \
	>>${TOOLS_DIR}/.tools-env
