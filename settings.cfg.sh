#! /bin/bash

# general
LSSTSW=${LSSTSW:-$HOME/lsstsw}
LSSTSW_BUILD_DIR=${LSSTSW_BUILD_DIR:-${LSSTSW}/build}

BUILDBOT_SUCCESS=0
BUILDBOT_FAILURE=1
BUILDBOT_WARNING=2

# lsstswBuild.sh
# options passed to ./create_xlinkdocs.sh as cli options
DOC_PUSH_USER=${DOC_PUSH_USER:-"buildbot"}
DOC_PUSH_HOST=${DOC_PUSH_HOST:-"lsst-dev.ncsa.illinois.edu"}
DOC_PUSH_PATH=${DOC_PUSH_PATH:-"/lsst/home/buildbot/public_html/doxygen"}

# create_xlinkdocs.sh
DOC_REPO_URL=${DOC_REPO_URL:-"https://github.com/lsst/lsstDoxygen.git"}
DOC_REPO_NAME=${DOC_REPO_NAME:-"lsstDoxygen"}
DOC_REPO_DIR=${DOC_REPO_DIR:-"${LSSTSW_BUILD_DIR}/${DOC_REPO_NAME}"}

# runManifestDemo.sh
DEMO_ROOT=${DEMO_ROOT:-"https://github.com/lsst/lsst_dm_stack_demo/archive/master.tar.gz"}
DEMO_TGZ=${DEMO_TGZ:-"lsst_dm_stack_demo-master.tar.gz"}
