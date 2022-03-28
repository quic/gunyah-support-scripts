# © 2021 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

SOURCE_ROOT=${0%/*}
PROGNAME=${0##*/}

getopt -T || GETOPT_STATUS=$?

die() {
    echo "${PROGNAME:-(unknown program)}: $*" >&2
    exit ${EXIT_STATUS:1}
}

if [[ $GETOPT_STATUS -ne 4 ]]; then
    die "getopt from util-linux required"
fi

nonoption=
declare -A arguments
parse_argument() {
    local opts=${1}
    shift

    local args=$(getopt -o '' \
        --longoptions $opts \
        --name "$PROGNAME" -- "$@") ||
        exit $?

    eval set -- "$args"

    while true; do
        case "${1}" in
        --)
            shift
            nonoption=("$@")
            break
            ;;
        --*)
            if [[ $opts = *${1#--}:* ]]; then
                arguments[${1#--}]="$2"
                shift
            else
                arguments[${1#--}]=""
            fi
            shift
            ;;
        *)
            die "parse_argument: internal error!"
            ;;
        esac
    done

    return ${#arguments[@]}
}

get_argument() {
    local -n argument_name=${2}

    if [[ ${arguments[${1}]+set} = set ]]; then
        argument_name=${arguments[${1}]}
    elif [[ $# -eq 3 ]]; then
        argument_name=$(${3})
    fi
}

git_clone() {
    local remote="${1}"
    local options="${2}"
    shift 2
    declare -a branch=("$@")

    for ((i = 0; i < $#; i = i + 2)); do
        echo "[GIT] ${remote}${branch[i]}"
        rm -rf ${branch[i]}

        git clone ${remote}${branch[i]} \
            --single-branch --branch=${branch[i + 1]} \
            ${options} .repos/${branch[i]} || {
            return 1
        } && {
            local -n rp=${branch[i]//[-.]/_}
            rp="${PWD}/.repos/${branch[i]}"
            echo "   cloned at: ${rp}"
        }
    done

    return 0
}
