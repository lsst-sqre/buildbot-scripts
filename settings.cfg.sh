#! /bin/bash

SCM_SERVER="github.com"
DEMO_ROOT="https://dev.lsstcorp.org/cgit/contrib/demos/lsst_dm_stack_demo.git/snapshot"
DEMO_TGZ="lsst_dm_stack_demo-master.tar.gz"
LSSTSW=${LSSTSW:-$HOME}
BUILD_DIR=${BUILD_DIR:-${HOME}/build}

BUILDBOT_SUCCESS=0
BUILDBOT_FAILURE=1
BUILDBOT_WARNING=2
