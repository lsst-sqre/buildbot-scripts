#!/bin/bash
#  Install the DM code stack using the lsstsw package procedure: rebuild

# /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\
#  This script modifies the actual DM stack on the cluster. It therefore 
#  explicitly checks literal strings to ensure that non-standard buildbot 
#  expectations regarding the 'work' directory location are  equivalent.
# /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\

SCRIPT_DIR=${0%/*}
source ${SCRIPT_DIR}/settings.cfg.sh
source ${LSSTSW}/bin/setup.sh

# Reuse an existing lsstsw installation
BUILDER_NAME=""
BUILD_NUMBER="0"
FAILED_LOGS="FailedLogs"
BUILD_DOCS="yes"
RUN_DEMO="yes"
PRODUCT=""

# Buildbot remotely invokes scripts with a stripped down environment.  
umask 002

print_error() {
    >&2 echo $@
}

options=(getopt --long builder_name:,build_number:,branch:,product,skip_docs,skip_demo -- "$@")
while true
do
    case "$1" in
        --builder_name) BUILDER_NAME=$2   ; shift 2 ;;
        --build_number) BUILD_NUMBER="$2" ; shift 2 ;;
        --branch)       BRANCH=$2         ; shift 2 ;;
        --product)      PRODUCT=$2        ; shift 2 ;;
        --skip_docs)    BUILD_DOCS="no"   ; shift 1 ;;
        --skip_demo)    RUN_DEMO="no"     ; shift 1 ;;
        --) shift ; break ;;
        *) [ "$*" != "" ] && echo "Parsed options; arguments left are:$*:"
            break;;
    esac
done

if [ "${BRANCH}" == "None" ]; then
    BRANCH="master"
else
    BRANCH="${BRANCH} master"
fi

export REF_LIST=`echo $BRANCH | sed  -e "s/ \+ / /g" -e "s/^/ /" -e "s/ $//" -e "s/ / -r /g"`

# print "settings"

settings=(
    BUILDER_NAME
    BUILD_NUMBER
    BRANCH
    PRODUCT
    BUILD_DOCS
    RUN_DEMO
    REF_LIST
    LSSTSW
    BUILD_DIR
    DOC_PUSH_USER
    DOC_PUSH_HOST
    DOC_PUSH_PATH
    DOC_REPO_URL
    DOC_REPO_NAME
    DOC_REPO_DIR
    DEMO_ROOT
    DEMO_TGZ
)

for i in ${settings[*]}
do
    eval echo "${i}: " \$$i
done

# print the "env"
echo ""
echo "### ENV ###"
printenv

mkdir -p ${BUILD_DIR}/$FAILED_LOGS
if [ $? -ne 0 ]; then
    print_error "Failed prior to stack rebuild; user unable to write to directory: ${BUILD_DIR}/$FAILED_LOGS"
    exit $BUILDBOT_FAILURE
fi

# Rebuild the stack if a git pkg changed. 
if [ ! -f ${LSSTSW}/bin/rebuild ]; then
     print_error "Failed to find 'rebuild'." 
     exit $BUILDBOT_FAILURE
fi
echo "Rebuild is commencing....stand by; using $REF_LIST"
${LSSTSW}/bin/rebuild $REF_LIST $PRODUCT
RET=$?

# Set current build tag (also used as eups tag per installed package).
eval "$(grep -E '^BUILD=' "$BUILD_DIR"/manifest.txt | sed -e 's/BUILD/TAG/')"

BUILD_STATUS="success" && (( $RET != 0 )) && BUILD_STATUS="failure"
echo "$TAG:$BUILD_NUMBER:$BUILD_STATUS:$BRANCH" >> ${BUILD_DIR}/eupsTag_buildbotNum

if [ $RET -eq 0 ]; then
    print_error "The DM stack has been installed at $LSSTSW with tag: $TAG."
else
    # Archive the failed build artifacts, if any found.
    mkdir -p ${BUILD_DIR}/$FAILED_LOGS/$BUILD_NUMBER
    for product in ${BUILD_DIR}/[[:lower:]]*/ ; do
        PACKAGE=`echo $product | sed -e "s/^.*\/build\///"  -e "s/\///"`
        PKG_FAIL_DIR=${BUILD_DIR}/$FAILED_LOGS/$BUILD_NUMBER/${PACKAGE}/
        # Are there failed tests?
        if [ -n "$(ls -A  $product/tests/.tests/*.failed 2> /dev/null)" ]; then
            mkdir -p  $PKG_FAIL_DIR
            for i in $product/tests/.tests/*.failed; do
                cp -p $i  $PKG_FAIL_DIR/.
            done
            for i in _build.log _build.tags _build.sh; do
                cp -p $product/$i $PKG_FAIL_DIR/.
            done
        # Are there error messages littered in the output?
        elif [ -e $product/_build.log ] && \
            [  ! `grep -qs '\*\*\* \|ERROR ' $product/_build.log` ]; then
            mkdir -p $PKG_FAIL_DIR
            for i in _build.log _build.tags _build.sh; do
                cp -p $product/$i $PKG_FAIL_DIR/.
            done
        fi
    done
    if [ "`ls -A ${BUILD_DIR}/$FAILED_LOGS/$BUILD_NUMBER`" != "" ]; then
        print_error "Failed during rebuild of DM stack." 
        echo "The following build artifacts are in directory: ${BUILD_DIR}/$FAILED_LOGS/$BUILD_NUMBER/"
        ls ${BUILD_DIR}/$FAILED_LOGS/$BUILD_NUMBER/*
    else
        print_error "Failed during setup prior to stack rebuild."
    fi
    exit $BUILDBOT_FAILURE 
fi  


# Build doxygen documentation
if [ $BUILD_DOCS == "yes" ]; then
    echo "Start Documentation build at: `date`"
    ${SCRIPT_DIR}/create_xlinkdocs.sh --type "master" --user $DOC_PUSH_USER --host $DOC_PUSH_HOST --path $DOC_PUSH_PATH
    RET=$?

    if [ $RET -eq 2 ]; then
        print_error "*** Doxygen documentation returned with a warning."
        print_error "*** Review the Buildbot 'stdio' log for build: $BUILD_NUMBER."
        exit $BUILDBOT_WARNING
    elif [ $RET -ne 0 ]; then
        print_error "*** FAILURE: Doxygen document was not installed."
        print_error "*** Review the Buildbot 'stdio' log for build: $BUILD_NUMBER."
        exit $BUILDBOT_FAILURE
    fi
    echo "Doxygen Documentation was installed successfully."
else
    echo "Skipping Documentation build."
fi

#=================================================================
# Then the BB_LastTag file is updated since full processing completed 
# successfully.
echo -n $TAG >  ${BUILD_DIR}/BB_Last_Tag
od -bc ${BUILD_DIR}/BB_Last_Tag

#=================================================================
# Finally run a simple test of package integration
if [ $RUN_DEMO == "yes" ]; then
    echo "Start Demo run at: `date`"
    ${SCRIPT_DIR}/runManifestDemo.sh --builder_name $BUILDER_NAME --build_number $BUILD_NUMBER --tag $TAG  --small
    RET=$?

    if [ $RET -eq 2 ]; then
        print_error "*** The simple integration demo completed with some statistical deviation in the output comparison."
        exit $BUILDBOT_WARNING
    elif [ $RET -ne 0 ]; then
        print_error "*** There was an error running the simple integration demo."
        print_error "*** Review the Buildbot 'stdio' log for build: $BUILD_NUMBER."
        exit $BUILDBOT_FAILURE
    fi
    echo "The simple integration demo was successfully run."
else
    echo "Skipping Demo."
fi
