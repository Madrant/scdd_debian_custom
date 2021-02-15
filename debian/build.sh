# $@ - additional simple-cdd parameters
#
# Use export SIMPLE_CDD_DISK_LABEL="label" to set CD label

# Please install following packages: simple-cdd sed grep

# Exit on error
set -e

# Global variables
SCRIPT_DIR="$(dirname $(readlink -f $0))"

# Export additional global variables
if [ -f "${SCRIPT_DIR}/export" ]
then
    source "${SCRIPT_DIR}/export"
fi

# Call pre-build script
if [ -x "${SCRIPT_DIR}/pre-build.sh" ]
then
    echo "Executing pre-build script"
    ./pre-build.sh
fi

# Call simple-cdd to create debian CD
set +e
    build-simple-cdd \
	--dist ${DEBIAN_RELEASE} \
	--conf ./simple-cdd.conf \
	--dvd \
	--verbose \
	$@
    ret=$?
set -e

if [ ${ret} -ne 0 ]
then
    echo "build-simple-cdd failed"
    exit 1
fi

# Call post-build script
if [ -x "${SCRIPT_DIR}/post-build.sh" ]
then
    echo "Executing post-build script"
    DEBIAN_RELEASE=${DEBIAN_RELEASE} ./post-build.sh
fi

echo "$0 completed"
exit 0
