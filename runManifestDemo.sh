#! /bin/bash
# Run the demo code to test DM algorithms

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
source ${SCRIPT_DIR}/settings.cfg.sh
source ${LSSTSW}/bin/setup.sh

#--------------------------------------------------------------------------
# Standalone invocation for gcc master stack:
#--------------------------------------------------------------------------
# First: setup lsstsw stack
# cd $lsstsw/build
# /lsst/home/buildbot/RHEL6/scripts/runManifestDemo.sh --small
# or
# /lsst/home/buildbot/RHEL6/scripts/runManifestDemo.sh

#--------------------------------------------------------------------------
usage() {
    echo "Usage: $0 [options]"
    echo "Initiate demonstration run."
    echo
    echo "Options:"
    echo "              --tag <id> : eups-tag for eups-setup or defaults to latest master build."
    echo "                 --small : to use small dataset; otherwise a mini-production size will be used."
    exit $BUILDBOT_FAILURE
}

print_error() {
    >&2 echo $@
}

TAG=""
SIZE=""
SIZE_EXT=""

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


cd $BUILD_DIR

# Setup either requested tag or last successfully built lsst_distrib
if [ -n "$TAG" ]; then
    setup -t $TAG lsst_distrib 
else
    setup -j lsst_distrib
    cd $LSST_DISTRIB_DIR/../
    VERSION=`ls | sort -r -n -t+ +1 -2 | head -1`
    setup lsst_distrib $VERSION
fi
#*************************************************************************
echo "----------------------------------------------------------------"
echo "EUPS-tag: $TAG     Version: $VERSION"
echo "Dataset size: $SIZE"
echo "Current `umask -p`"
echo "Setup lsst_distrib "
eups list  -s
echo "-----------------------------------------------------------------"

if [ -z  "$PIPE_TASKS_DIR" -o -z "$OBS_SDSS_DIR" ]; then
      print_error "*** Failed to setup either PIPE_TASKS or OBS_SDSS; both of  which are required by $DEMO_BASENAME"
      exit $BUILDBOT_FAILURE
fi

# Acquire and Load the demo package in buildbot work directory
echo "curl -kLo $DEMO_TGZ $DEMO_ROOT"
curl -kLo $DEMO_TGZ $DEMO_ROOT
if [ ! -f $DEMO_TGZ ]; then
    print_error "*** Failed to acquire demo from: $DEMO_ROOT."
    exit $BUILDBOT_FAILURE
fi

echo "tar xzf $DEMO_TGZ"
tar xzf $DEMO_TGZ
if [ $? != 0 ]; then
    print_error "*** Failed to unpack: $DEMO_TGZ"
    exit $BUILDBOT_FAILURE
fi

DEMO_BASENAME=`basename $DEMO_TGZ | sed -e "s/\..*//"`
echo "DEMO_BASENAME: $DEMO_BASENAME"
cd $DEMO_BASENAME
if [ $? != 0 ]; then
    print_error "*** Failed to find unpacked directory: $DEMO_BASENAME"
    exit $BUILDBOT_FAILURE
fi

./bin/demo.sh --$SIZE
if [ $? != 0 ]; then
    print_error "*** Failed during execution of  $DEMO_BASENAME"
    exit $BUILDBOT_FAILURE
fi

# Add column position to each label for ease of reading the output comparison
COLUMNS=`head -1 detected-sources$SIZE_EXT.txt| sed -e "s/^#//" `
j=1
NEWCOLUMNS=`for i in $COLUMNS; do echo -n "$j:$i "; j=$((j+1)); done`
echo "Columns in benchmark datafile:"
echo $NEWCOLUMNS
echo "${LSSTSW}/lfs/bin/numdiff -# 11 detected-sources$SIZE_EXT.txt.expected detected-sources$SIZE_EXT.txt"
${LSSTSW}/lfs/bin/numdiff -# 11 detected-sources$SIZE_EXT.txt.expected detected-sources$SIZE_EXT.txt
if  [ $? != 0 ]; then
    print_error "*** Warning: output results not within error tolerance for: $DEMO_BASENAME"
    exit $BUILDBOT_WARNING
exit  $BUILDBOT_SUCCESS
fi
