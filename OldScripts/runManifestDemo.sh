#! /bin/bash
# Run the demo code to test DM algorithms

###############################################################################
###############################################################################
# 
# Due to the buildbot characteristic which always starts with a blank env,
# we need to collect and invoke the path info needed for a user run.
# 
# This script uses a Manifest list to setup the run environment
#
###############################################################################
###############################################################################


#/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
# GLOBALS to be sourced from SRPs globals header - when ready
#/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
ASTROMETRY_NET_DATA_DIR=/lsst/DC3/data/astrometry_net_data/
#/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/

DEBUG=debug

# Standalone invocation for gcc master stack:
# export LSST_HOME=/lsst/DC3/stacks/gcc445-RH6/28nov2011
# export LSST_DEVEL=/lsst/home/buildbot/RHEL6//buildslaves/lsst-build1/SMBRG/sandbox
# source loadLSST.sh
# cd /lsst/home/buildbot/RHEL6//builds/SMBRG/work
# /lsst/home/buildbot/RHEL6/scripts/runManifestDemo.sh  --builder_name "Dunno" --build_number "1" --manifest /lsst/home/buildbot/RHEL6//builds/SMBRG/work/lastSuccessfulBuildManifest.list 

#--------------------------------------------------------------------------
usage() {
#80 cols  ................................................................................
    echo "Usage: $0 [options] package"
    echo "Initiate demonstration run."
    echo
    echo "Options:"
    echo "                  --debug: print out extra debugging info"
    echo "        --manifest <path>: manifest list for eups-setup."
    echo "    --builder_name <name>: buildbot's build name assigned to run"
    echo "  --build_number <number>: buildbot's build number assigned to run"
    echo "--log_dest <buildbot@host:remotepath>: scp destination_path"
    echo "          --log_url <url>: URL for web-access to the build logs "
    echo "       --step_name <name>: assigned step name in build"
}
#--------------------------------------------------------------------------

# Setup LSST buildbot support fnunctions
source ${0%/*}/gitConstants.sh
source ${0%/*}/build_functions.sh
source ${0%/*}/gitBuildFunctions.sh

WEB_ROOT="/usr/local/home/buildbot/www/"

# -------------------
# -- get arguments --
# -------------------

options=$(getopt -l debug,builder_name:,build_number:,log_dest:,log_url:,step_name:,manifest: -- "$@")

BUILDER_NAME=""
BUILD_NUMBER=0
MANIFEST=
LOG_DEST=""
LOG_URL=""
STEP_NAME=""

while true
do
    case $1 in
        --debug)        DEBUG=true; shift;;
        --log_dest)
                LOG_DEST=$2;
                LOG_DEST_HOST=${LOG_DEST%%\:*}; # buildbot@master
                LOG_DEST_DIR=${LOG_DEST##*\:};  # /var/www/html/logs
                shift 2;;
        --log_url) LOG_URL=$2; shift 2;;
        --builder_name) BUILDER_NAME=$2; shift 2;;
        --build_number) BUILD_NUMBER=$2; shift 2;;
        --manifest)     MANIFEST=$2; shift 2;;
        --step_name)    STEP_NAME=$2; shift 2;;
        *) [ "$*" != "" ] && echo "parsed options; arguments left are:$*:"
             break;;
    esac
done


source $LSST_HOME/loadLSST.sh

eups admin clearCache -Z $LSST_DEVEL
eups admin buildCache -Z $LSST_DEVEL

#*************************************************************************
echo "BUILDER_NAME: $BUILDER_NAME"
echo "BUILD_NUMBER: $BUILD_NUMBER"
echo "MANIFEST: $MANIFEST"
echo "LOG_DEST: $LOG_DEST"
echo "LOG_URL: $LOG_URL"
echo "Current `umask -p`"
#*************************************************************************

WORK_DIR=`pwd`

##
# ensure full dependencies file is available
##
if [ ! -e $MANIFEST ] || [ "`cat $MANIFEST | wc -l`" = "0" ]; then
    usage
    echo "FAILURE: -----------------------------------------------------------"
    echo "Failed to find file: $MANIFEST, in buildbot work directory."
    echo "FAILURE: -----------------------------------------------------------"
    exit $BUILDBOT_FAILURE
fi


# Acquire and Load the demo package in buildbot work directory
echo "curl -kO $DEMO_ROOT/$DEMO_TGZ"
curl -kO $DEMO_ROOT/$DEMO_TGZ
if [ ! -f $DEMO_TGZ ]; then
    echo "FAILURE: -----------------------------------------------------------"
    echo "Failed to acquire demo from: $DEMO_ROOT/$DEMO_TGZ  ."
    echo "FAILURE: -----------------------------------------------------------"
    exit $BUILDBOT_FAILURE
fi

echo "tar xzf $DEMO_TGZ"
tar xzf $DEMO_TGZ
if [ $? != 0 ]; then
    echo "FAILURE: -----------------------------------------------------------"
    echo "Failed to unpack: $DEMO_TGZ"
    echo "FAILURE: -----------------------------------------------------------"
    exit $BUILDBOT_FAILURE
fi

DEMO_BASENAME=`basename $DEMO_TGZ | sed -e "s/\..*//"`
echo "DEMO_BASENAME: $DEMO_BASENAME"
cd $DEMO_BASENAME
if [ $? != 0 ]; then
    echo "FAILURE: -----------------------------------------------------------"
    echo "Failed to find unpacked directory: $DEMO_BASENAME"
    echo "FAILURE: -----------------------------------------------------------"
    exit $BUILDBOT_FAILURE
fi


# Setup the entire build environment for a demo run
#while read LINE; do
#    set $LINE
#    echo "Setting up: $1   $2"
#    setup -j $1 $2
#done < $MANIFEST

setup `grep obs_sdss $MANIFEST | awk '{ print $1 " " $2}'`

echo ""
echo " ----------------------------------------------------------------"
eups list  -s
echo "-----------------------------------------------------------------"
echo ""
echo "Current `umask -p`"

if [ -z  "$PIPE_TASKS_DIR" -o -z "$OBS_SDSS_DIR" ]; then
      echo "FAILURE: ----------------------------------------------------------"
      echo "Failed to setup either PIPE_TASKS or OBS_SDSS; both of  which are required by $DEMO_BASENAME"
      echo "FAILURE: ----------------------------------------------------------"
      exit $BUILDBOT_FAILURE
fi

pwd
echo "./bin/demo_small.sh"
./bin/demo_small.sh
if [ $? != 0 ]; then
    echo "FAILURE: -----------------------------------------------------------"
    echo "Failed during execution of  $DEMO_BASENAME"
    echo "FAILURE: -----------------------------------------------------------"
    exit $BUILDBOT_FAILURE
fi


# Add column position to each label for ease of reading the output comparison
COLUMNS=`head -1 detected-sources.txt| sed -e "s/^#//" `
j=1
NEWCOLUMNS=`for i in $COLUMNS; do echo -n "$j:$i "; j=$((j+1)); done`
echo "Columns in benchmark datafile:"
echo $NEWCOLUMNS
echo "$HOME/numdiff/bin/numdiff -# 11 detected-sources.txt.expected_small detected-sources.txt"
$HOME/numdiff/bin/numdiff -# 11 detected-sources.txt.expected_small detected-sources.txt
if  [ $? != 0 ]; then
    # preserve diff results
    #LOG_FILE="detected-sources.txt"
    #if [ "$LOG_DEST" ]; then
    #    if [ -f "$LOG_FILE" ]; then
    #        copy_log $LOG_FILE $LOG_FILE $LOG_DEST_HOST $LOG_DEST_DIR $BUILDER_NAME'/build/'$BUILD_NUMBER'/steps/'$STEP_NAME'/logs' $LOG_URL
    #    else
    #            print_error "WARNING: No $LOG_FILE present."
    #    fi
    #else
    #    print_error "WARNING: No archive destination provided for log file."
    #fi

    exit $BUILDBOT_WARNINGS
fi
exit  $BUILDBOT_SUCCESS
