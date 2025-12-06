#!/bin/bash

# install.sh - A script to download, verify, and install "crun"
#              (with "libkrun") from a specified release tag.
#
# Usage:
#   ./install_script.sh [-p INSTALL_DIR] [-t INSTALL_TAG] [-h]
#
# Options:
#   -p INSTALL_DIR  Specify the directory to install crun.
#   -t INSTALL_TAG  Specify the tag of the release to install.
#   -h              Display this help message and exit.
#
# Example:
#   ./install.sh -p /usr/local/bin -t v1.15

INSTALL_DIR=""
INSTALL_TAG=""
TEMP_DIR=""

readonly REPO="https://github.com/clickyotomy/krun/releases/download"
readonly LIB_PATH="/usr/local/lib64"
readonly CRUN_LD_SO_CONF="/etc/ld.so.conf.d/crun.conf"

# Configure the dynamic linker runtime bindings.
function configure_ldconfig() {
    echo "${LIB_PATH}" > "${CRUN_LD_SO_CONF}"
    ldconfig
}

# Get the ABI version of a library.
function abi_version() {
    readelf -d "${1}"  | grep 'SONAME' | awk -F'[][]' '{print $2}'
}

# Check if a binary exists.
function check_bin() {
    if ! command -v "${1}" &>/dev/null; then
        echo "error: command not found: ${1}"
        exit 1
    fi
}

# Display program usage.
function usage() {
    echo "usage: ${0} [-p PATH] [-t TAG] [-h]" 1>&2
    exit 1
}

# Download, verify and install the libraries and binaries.
function install() {
    args "${@}"

    local tar_base lib_abi bin_ver

    check_bin "curl"
    check_bin "sha1sum"
    check_bin "tar"
    check_bin "tee"
    check_bin "ls"
    check_bin "readelf"
    check_bin "ldconfig"

    TEMP_DIR="$(mktemp -d)"
    trap 'rm -rf -- "${TEMP_DIR}"' EXIT

    pushd "${TEMP_DIR}" >/dev/null || exit 1

    tar_base="release-$(uname -m)"

    curl -fsSLO "${REPO}/${INSTALL_TAG}/${tar_base}.tar.gz"
    curl -fsSLO "${REPO}/${INSTALL_TAG}/${tar_base}.sha1"

    if ! sha1sum --check --status --strict "${tar_base}.sha1"; then
        echo "error: tarball checksum failed"
        exit 1
    fi


    mkdir -p "${LIB_PATH}"
    mkdir -p "${INSTALL_DIR}"

    tar -xzf "${tar_base}.tar.gz" -C "${TEMP_DIR}"

    for lib in "${tar_base}/lib"*; do
        lib_rel=$(basename "${lib}")
        lib_abi="$(abi_version "${lib}")"
        mv "${lib}" "${LIB_PATH}"
        ln -sf "${LIB_PATH}/${lib_rel}" "${LIB_PATH}/${lib_abi}"
        chmod -w "${LIB_PATH}/${lib_rel}" "${LIB_PATH}/${lib_abi}"
    done

    configure_ldconfig

    bin_ver="${INSTALL_TAG:1}"
    chmod +x "${tar_base}/crun-${bin_ver}"
    mv "${tar_base}/crun-${bin_ver}" "${INSTALL_DIR}/crun-${bin_ver}"
    ln -sf "${INSTALL_DIR}/crun-${bin_ver}" "${INSTALL_DIR}/crun"
    ln -sf "${INSTALL_DIR}/crun-${bin_ver}" "${INSTALL_DIR}/krun"

    popd >/dev/null || exit 1
}

# Parse and validate arguments.
function args() {
    local OPTIND

    while getopts ":p:t:h" OPT; do
        case "${OPT}" in
        p)
            INSTALL_DIR="${OPTARG}"
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

    if [ -z "${INSTALL_DIR}" ] || [ -z "${INSTALL_TAG}" ]; then
        usage
    fi
}

install "${@}"
