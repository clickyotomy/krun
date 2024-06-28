#!/bin/bash

INSTALL_PATH=""
INSTALL_TAG=""

readonly REPO="https://github.com/clickyotomy/krun/releases/download/"

readonly RELEASE_DIR="release"
readonly TAR_GZIP="${RELEASE_DIR}.tar.gz"
readonly TAR_SHA1="${RELEASE_DIR}.sum"

readonly LIB_PATH="/usr/local/lib64"
readonly LD_LIBS="/lib:/lib64:/usr/lib:/usr/lib64:/usr/local/lib:${LIB_PATH}"


function check_bin() {
    if ! command -v "${1}" &>/dev/null; then
        echo "error: command not found: ${1}"
        exit 1
    fi
}

function abi_version() {
    readelf -d "${1}"  | grep 'SONAME' | awk -F'[][]' '{print $2}'
}

function usage() {
    echo "usage: ${0} [-p PATH] [-t TAG] [-h]" 1>&2
    exit 1
}

function install() {
    args "${@}"

    local tmp_dir

    check_bin "curl"
    check_bin "sha1sum"
    check_bin "tar"
    check_bin "tee"
    check_bin "ls"
    check_bin "readelf"

    curl -fsSLO "${REPO}/${2}/$(uname -m)/${TAR_GZIP}"
    curl -fsSLO "${REPO}/${2}/$(uname -m)/${TAR_SHA1}"

    if ! sha1sum --check --status --strict "${TAR_SHA1}"; then
        echo "error: tarball checksum failed"
        exit 1
    fi

    tmp_dir="$(mktemp)"
    trap 'rm -rf -- "${tmp_dir}"' EXIT

    mkdir -p "${LIB_PATH}"

    pushd "${tmp_dir}" || exit 1

    tar -xzf "${TAR_GZIP}"
    mkdir -p "${LIB_PATH}"

    for lib in "${RELEASE_DIR}"/lib*; do
        mv "${lib}" "${LIB_PATH}"
        ln -sf "${LIB_PATH}/${lib}" "${LIB_PATH}/$(abi_version "${lib}")"
    done

	echo -e "#!/bin/sh\nLD_LIBRARY_PATH=\"${LD_LIBS}\" ${1}/crun \$@" >krun
    chmod +x crun krun
    mv crun krun "${1}/"

    popd || exit 1
}

function args() {
    local OPTIND

    while getopts ":p:t:h" OPT; do
        case "${OPT}" in
        p)
            INSTALL_PATH="${OPTARG}"
            ;;
        t)
            INSTALL_TAG="${OPTARG}"
            ;;
        h)
            usage
            ;;
        *)
            usage
            ;;
        esac
    done
    shift $((OPTIND - 1))

    if [ -z "${INSTALL_PATH}" ] || [ -z "${INSTALL_TAG}" ]; then
        usage
    fi
}

install "${@}"
