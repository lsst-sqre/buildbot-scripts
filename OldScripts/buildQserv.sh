#!/bin/bash
#
#  /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\
# |           R U N S    O N     L S S T - B U I L D 8     O N L Y         |
#  \/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
# 
# lsst-build8 has qserv required 'root' 3rd party software installed.
#

source ${0%/*}/gitConstants.sh

# Setup qserv installation directory
export WORK=`pwd`
# $WORK/build = official installation directory; 
# $WORK/src = tool source directory
export Q_ALL_SRC_DIR=$WORK/src
export QSERV_SRC_DIR=$WORK/src/qserv
export QSERV_BASE_DIR=$WORK/build

# Following is provided by buildbot's setup of environment variables
# export LSST_DMS=git@git.lsstcorp.org:LSST/DMS

mkdir -p $Q_ALL_SRC_DIR
cd $Q_ALL_SRC_DIR

git clone $LSST_DMS/qserv.git
if [ $? != 0 ]; then
   echo "Error: unable to acquire qserv git repository: $LSST_DMS/qserv.git"
   exit $BUILDBOT_FAILURE
fi
echo "=============================================================="
cd qserv
git checkout master
git submodule init
git submodule update


#/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
#   T B D         T B D      T B D     T B D    T B D     T B D
# Need to test that code mentioned in:
#    work/buid/qserv/admin/bootstrap/qserv-install-deps-sl6.sh
# had been installed at the system level
#echo "==============================================================="
#echo "Ensure installation of root-installed dependencies occurred."
#echo "Root-installed depdendencies already installed."
#echo "==============================================================="
#   T B D         T B D      T B D     T B D    T B D     T B D
#/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/


cd $QSERV_SRC_DIR
# Need to mangle default locations for the qserv installation products
if [ ! -f qserv-build.conf.example ]; then
   echo "Error: unable to find sample configuration file: qserv-build.conf.example"
   exit $BUILDBOT_FAILURE
fi
echo "=============================================================="
cp qserv-build.conf.example qserv-build.conf.example_ORG
cat qserv-build.conf.example | sed -e "s^base_dir *=.*^base_dir=$QSERV_BASE_DIR^" -e "s^master *=.*^master=127.0.0.1^"  > qserv-build.conf.example_NEW
cp qserv-build.conf.example_NEW qserv-build.conf
echo "==============================================================="
diff qserv-build.conf.example_ORG  qserv-build.conf
echo ""
echo "If {base_dir=  &&  master=} not listed above,  config update FAILED"
echo "==============================================================="

echo "==============================================================="
echo "PATH: $PATH"
echo "LD_LIBRARY: $LD_LIBRARY"
printenv
echo "==============================================================="

cd $QSERV_SRC_DIR
scons
if [ $? != 0 ]; then
   echo "Error: unable to build: qserv"
   exit $BUILDBOT_FAILURE
fi
echo "=============================================================="
echo " QSERV installed"
echo "==============================================================="

echo "Configuration Files"
ls -al ~/.lsst/qserv*

if [ ! -f $QSERV_BASE_DIR/qserv-env.sh ]; then
   echo "Error: no start-up script: $QSERV_BASE_DIR/qserv-env.sh"
   exit $BUILDBOT_FAILURE
fi
echo "==============================================================="
printenv
echo "==============================================================="
source $QSERV_BASE_DIR/qserv-env.sh
if [ $? != 0 ]; then
   echo "Error: failed during: source $QSERV_BASE_DIR/qserv-env.sh"
   exit $BUILDBOT_FAILURE
fi

printenv

echo "==============================================================="
echo "qserv-admin found at: `which qserv-admin`"
qserv-admin --start
if [ $? != 0 ]; then
   echo "Error: failed during: qserv-admin"
   qserv-admin --stop  --dbpass \"changeme\";
   exit $BUILDBOT_FAILURE
fi
echo "qserv started"
qserv-admin --stop  --dbpass \"changeme\"; rm -f ${QSERV_BASE}/xrootd-run/result/*
if [ $? != 0 ]; then
   echo "Error: failed during: qserv-admin ....stop"
   qserv-admin --stop  --dbpass \"changeme\";
   exit $BUILDBOT_FAILURE
fi
echo "qserv stopped"
qserv-admin --start
if [ $? != 0 ]; then
   echo "Error: failed during: qserv-admin --start"
   qserv-admin --stop  --dbpass \"changeme\";
   exit $BUILDBOT_FAILURE
fi
echo "qserv started"

echo "==============================================================="
echo "Testing functional tests"
qserv-testdata.py
if [ $? != 0 ]; then
   echo "Error: failed to successfully run test suite"
   echo "       Look in $QSERV_BASE_DIR/tmp/qservTest_caseID/outputs"
   qserv-admin --stop  --dbpass \"changeme\";
   exit $BUILDBOT_FAILURE
fi

echo "==============================================================="
echo "Unit Testing"
qserv-testunit.py
if [ $? != 0 ]; then
   echo "Error: failed to successfully run unit tests"
   qserv-admin --stop  --dbpass \"changeme\";
   exit $BUILDBOT_FAILURE
fi
echo "==============================================================="
echo "Terminating Qserv service in order to allow Buildbot to disconnect."
qserv-admin --stop  --dbpass \"changeme\"; rm -f ${QSERV_BASE}/xrootd-run/result/*
if [ $? != 0 ]; then
   echo "Error: failed during final service shutdown: qserv-admin ....stop"
   echo "Kill the qserv server process in order to terminate the buildbot slave."
   exit $BUILDBOT_FAILURE
fi
echo "qserv stopped"

echo " "
echo "==============================================================="
echo " /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\ "
echo "|      Remember to:  'source  $QSERV_BASE_DIR/qserv-env.sh'          |"
echo " \/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/ "
echo "==============================================================="
exit $BUILDBOT_SUCCESS

