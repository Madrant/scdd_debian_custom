#!/bin/bash

# simple-cdd pre-build script
#
# Clear simple-cdd cache and drop packages database

# Exit on error
set -e

# Setup directories
SCRIPT_DIR="$(dirname $(readlink -f $0))"

LOCAL_PACKAGES="${SCRIPT_DIR}/local_packages"

# Check directories for presence
if [ ! -d "${LOCAL_PACKAGES}" ]; then
    echo "Error: no such directory: '${LOCAL_PACKAGES}'"
    exit 1
fi

# Local packages will be installed during OS setup
echo "Local packages:"
ls -l "${LOCAL_PACKAGES}/"

# Clear simple-cdd package cache for copied local packages
DEB_CACHE="${SCRIPT_DIR}/tmp/mirror/pool/main"

echo "Clearing simple-cdd package cache..."

pushd "${LOCAL_PACKAGES}"
    for f in *.deb; do
        if [ "${f}" = "*.deb" ]; then
            echo "No deb packages found at '${LOCAL_PACKAGES}'"
            break
        fi

        package=$(dpkg -f "${f}" Package)
        letter=${package:0:1}

        if [ -d "${DEB_CACHE}/${letter}/${package}" ]; then
            echo "Cleaning cache for package: '$package' letter: '${letter}'"
            rm -rf "${DEB_CACHE}/${letter}/${package}/"
        fi
    done
popd

echo "Deleting simple-cdd database files..."
rm -f "${SCRIPT_DIR}"/tmp/mirror/db/*.db

echo "simple-cdd package cache cleared"

# Exit
echo "$0 completed"
exit 0
