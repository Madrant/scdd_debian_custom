#!/bin/bash

# simple-cdd pre-build script
#
# Allows to change disk label, change build date and time

# Exit on error
set -e

# Global variables
SCRIPT_DIR="$(dirname $(readlink -f $0))"

MD5SUM_FILE=md5sum.txt

echo "$0 started"

# check required variables
if [ -z "${DEBIAN_RELEASE}" ]; then
    echo "Error: DEBIAN_RELEASE is not set"
    exit 1
fi

# Setup CD root directory
CD1_ROOT="${SCRIPT_DIR}/tmp/cd-build/${DEBIAN_RELEASE}/CD1"
if [ ! -d "${CD1_ROOT}" ]; then
    echo "Error: simple-cdd CD root directory not found: '${CD1_ROOT}'"
    exit 1
fi
echo "simple-cdd CD root directory: '${CD1_ROOT}'"

# Setup isolinux directory
ISOLINUX_ROOT="${SCRIPT_DIR}/tmp/cd-build/${DEBIAN_RELEASE}/boot1"
if [ ! -d "${ISOLINUX_ROOT}" ]; then
    echo "Error: simple-cdd isolinux directory not found: '${ISOLINUX_ROOT}'"
    exit 1
fi
echo "simple-cdd isolinux root directory: '${ISOLINUX_ROOT}'"

# Get CD build command
MKISOFS_CMD=$(cat "${CD1_ROOT}/.disk/mkisofs")
if [ -z "${MKISOFS_CMD}" ]; then
    echo "Error: CD build command located in '${CD1_ROOT}/.disk/mkisofs' not found"
    exit 1
fi
echo "simple-cdd CD build command: '${MKISOFS_CMD}'"

# Functions

# Regenerate CD iso image
regenerate_cd_image() {
    if [ -z "${MKISOFS_CMD}" ]; then
        echo "Error: mkisofs command is empty"
        exit 1
    fi

    echo "Disk regeneration requested"

    pushd "${CD1_ROOT}/../"
        echo "Running xorriso command:"
        echo "${MKISOFS_CMD}"
        eval ${MKISOFS_CMD}
    popd
}

# Change CD label to $1
#
# $1 - disk label
change_cd_label() {
    local disk_label="${1}"

    # Get current label from autorun.inf
    label=$(cat "${CD1_ROOT}/autorun.inf" | grep label)
    label=${label#*label=}                 # remove 'label=' prefix
    label=$(echo ${label} | sed 's/\r//g') # remove windows \r symbols

    # Change label in autorun.inf:
    # Note: sed standard delimiter '/' changed intentionally
    # to allow backlash ('/') usage in CD label:
    echo "Changing CD autorun.inf label from '${label}' to '${disk_label}'"
    sed -i "s=${label}=${disk_label}=g" "${CD1_ROOT}/autorun.inf"

    echo "New autorun.inf contents:"
    cat "${CD1_ROOT}/autorun.inf"

    # Update md5sum of a modified autorun.inf:
    MD5SUM_FILE=md5sum.txt

    cat "${CD1_ROOT}/${MD5SUM_FILE}" | grep -v "autorun.inf" > "${CD1_ROOT}/${MD5SUM_FILE}.new"
    pushd "${CD1_ROOT}"
        md5sum "./autorun.inf" >> "${CD1_ROOT}/${MD5SUM_FILE}.new"
    popd

    mv -f "${CD1_ROOT}/${MD5SUM_FILE}.new" "${CD1_ROOT}/${MD5SUM_FILE}"
    rm -f "${CD1_ROOT}/${MD5SUM_FILE}.new"

    # Get volume name from mkisofs command:
    volume=$(echo ${MKISOFS_CMD} | grep -o "\-V '.*'" | grep -o "'.*'")
    echo "xorriso volume name: ${volume}"

    # Modify mkisofs command
    MKISOFS_CMD=$(echo ${MKISOFS_CMD} | sed "s=${volume}='${disk_label}'=g")
}

# Calculate md5sums for all files in a given directory
#
# $1 - directory
# $2 - filename
calculate_md5sum() {
    local directory="${1}"
    local filename="${2}"

    # Check directory for presence
    if [ ! -d "${directory}" ]; then
        echo "Error: No such directory '${directory}'"
        exit 1
    fi

    # Use default globals
    if [ -z "${filename}" ]; then
        filename="${MD5SUM_FILE}"
        echo "Using default filename: '${filename}'"
    fi

    echo "Calculating md5 sums in '${directory}' into '${filename}'"

    pushd "${directory}"
        # Create empty file
        echo -n "" > "${filename}"

        # Search for all files and calculate checksum
        find . -type f ! -path "./${filename}"			\
                       ! -path "./isolinux/isolinux.bin"	\
                       -exec md5sum {} >> "${filename}" \;
    popd
}

# Set date and time of a files newer than a date provided inside target directory
#
# $1 - directory to modify date time
# $2 - date time in format 201809120945.00
# if first param is not set - global variable RELEASE_DATE is used
correct_date_time() {
    local d="${1}"
    local datetime="${2}"

    if [ ! -d "${d}"  ]
    then
        print_err "corect_date_time: no such directory: '${d}'"
        exit 1
    fi

    if [ -z "${datetime}" ]
    then
        # Try to use RELEASE_DATE
        if [ ! -z "${RELEASE_DATE}" ]
        then
            echo "correct_date_time: using global time '${RELEASE_DATE}'"
            datetime="${RELEASE_DATE}"
        else
            echo "correct_date_time: no time to use"
            return
        fi
    fi

    echo "correct_date_time: correcting datetime to '${datetime}' in '${d}'"

    local d_parent=$(dirname "${d}")
    local d_name=$(basename "${d}")

    pushd "${d_parent}"
        local reftimefile="/tmp/__datetime.remove_me"
        touch -t "${datetime}" "${reftimefile}"

        find "${d_name}" -newer "${reftimefile}" -exec touch -c -h -t "${datetime}" {} +

        rm -f "${reftimefile}"
    popd
}

regenerate_cd=0

# Check if SIMPLE_CDD_DISK_LABEL is set and update disk label
if [ -z "${SIMPLE_CDD_DISK_LABEL}" ]; then
    echo "SIMPLE_CDD_DISK_LABEL not set - disk label will not be updated"
else
    echo "SIMPLE_CDD_DISK_LABEL set: '${SIMPLE_CDD_DISK_LABEL}'"
    change_cd_label "${SIMPLE_CDD_DISK_LABEL}"
    regenerate_cd=1
fi

# Calculate checksums for all the files on the disk (simple-cdd lost some)
calculate_md5sum "${CD1_ROOT}"		"${MD5SUM_FILE}"
calculate_md5sum "${ISOLINUX_ROOT}"	"${MD5SUM_FILE}"

cat "${ISOLINUX_ROOT}/${MD5SUM_FILE}" >> "${CD1_ROOT}/${MD5SUM_FILE}"
rm -f "${ISOLINUX_ROOT}/${MD5SUM_FILE}"

regenerate_cd=1

# Change date and time of CD files older than release date
correct_date_time "${CD1_ROOT}"
correct_date_time "${ISOLINUX_ROOT}"
regenerate_cd=1

# Regenerate CD if needed
if [ ${regenerate_cd} -eq 1 ]; then
    regenerate_cd_image
fi

echo "$0 completed"
exit 0
