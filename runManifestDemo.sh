#! /bin/bash
# Run the demo code to test DM algorithms

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
# shellcheck source=./settings.cfg.sh
source "${SCRIPT_DIR}/settings.cfg.sh"
# shellcheck source=../lsstsw/bin/setup.sh
source "${LSSTSW}/bin/setup.sh"

print_error() {
    >&2 echo -e "$@"
}

fail() {
    code=${2:1}
    [[ -n $1 ]] && print_error "$1"
    # shellcheck disable=SC2086
    exit $code
}

#--------------------------------------------------------------------------
# Standalone invocation for gcc master stack:
#--------------------------------------------------------------------------
# First: setup lsstsw stack
# cd $lsstsw/build
# ./runManifestDemo.sh --small
# or
# ./runManifestDemo.sh

#--------------------------------------------------------------------------
usage() {
    print_error "Usage: $0 [options]"
    print_error "Initiate demonstration run."
    print_error
    print_error "Options:"
    print_error "              --tag <id> : eups-tag for eups-setup or defaults to latest master build."
    print_error "                 --small : to use small dataset; otherwise a mini-production size will be used."
    fail
}


TAG=""
SIZE=""
SIZE_EXT=""

# shellcheck disable=SC2034
options=$(getopt -l help,small,tag: -- "$@")

while true
do
    case $1 in
        --help)         usage;;
        --small)        SIZE="small";
                        SIZE_EXT="_small";
                        shift 1;;
        --tag)          TAG=$2; shift 2;;
        --)             break ;;
        *)              [ "$*" != "" ] && usage;
                        break;;
    esac
done


cd "$LSSTSW_BUILD_DIR"

# Setup either requested tag or last successfully built lsst_apps
if [[ -n $TAG ]]; then
    setup -t "$TAG" lsst_apps
else
    setup -j lsst_apps
    cd "${LSST_APPS_DIR}/../"
    VERSION=$(find . | sort -r -n -t+ +1 -2 | head -1)
    setup lsst_apps "$VERSION"
fi
#*************************************************************************
echo "----------------------------------------------------------------"
echo "EUPS-tag: ${TAG}     Version: ${VERSION}"
echo "Dataset size: ${SIZE}"
echo "Current $(umask -p)"
echo "Setup lsst_apps"
eups list  -s
echo "-----------------------------------------------------------------"

if [[ -z $PIPE_TASKS_DIR || -z $OBS_SDSS_DIR ]]; then
    fail "*** Failed to setup either PIPE_TASKS or OBS_SDSS; both of  which are required by ${DEMO_BASENAME}"
fi

# Acquire and Load the demo package in buildbot work directory
echo "curl -kLo ${DEMO_TGZ} ${DEMO_ROOT}"
curl -kLo "$DEMO_TGZ" "$DEMO_ROOT"
if [[ ! -f $DEMO_TGZ ]]; then
    fail "*** Failed to acquire demo from: ${DEMO_ROOT}."
fi

echo "tar xzf $DEMO_TGZ"
if ! tar xzf "$DEMO_TGZ"; then
    fail "*** Failed to unpack: ${DEMO_TGZ}"
fi

DEMO_BASENAME=$(basename "$DEMO_TGZ" | sed -e "s/\..*//")
echo "DEMO_BASENAME: $DEMO_BASENAME"
if [[ ! -d $DEMO_BASENAME ]]; then
    fail "*** Failed to find unpacked directory: ${DEMO_BASENAME}"
fi

cd "$DEMO_BASENAME"

if ! ./bin/demo.sh --$SIZE; then
    fail "*** Failed during execution of ${DEMO_BASENAME}"
fi

# Add column position to each label for ease of reading the output comparison
COLUMNS=$(head -1 detected-sources$SIZE_EXT.txt| sed -e "s/^#//")
j=1
NEWCOLUMNS=$(for i in $COLUMNS; do echo -n "$j:$i "; j=$((j+1)); done)
echo "Columns in benchmark datafile:"
echo "$NEWCOLUMNS"
echo "./bin/compare detected-sources${SIZE_EXT}.txt"
if ! ./bin/compare detected-sources${SIZE_EXT}.txt; then
    fail "*** Warning: output results not within error tolerance for: ${DEMO_BASENAME}"
fi
