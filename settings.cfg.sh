#! /bin/bash

# general
LSSTSW=${LSSTSW:-$HOME}
BUILD_DIR=${BUILD_DIR:-${HOME}/build}

BUILDBOT_SUCCESS=0
BUILDBOT_FAILURE=1
BUILDBOT_WARNING=2

# doc build
DOC_REPO_URL="https://github.com/lsst/lsstDoxygen.git"
DOC_REPO_NAME="lsstDoxygen"
DOC_REPO_DIR=${BUILD_DIR}/${DOC_REPO_NAME}

# demo run
DEMO_ROOT="https://dev.lsstcorp.org/cgit/contrib/demos/lsst_dm_stack_demo.git/snapshot"
DEMO_TGZ="lsst_dm_stack_demo-master.tar.gz"
