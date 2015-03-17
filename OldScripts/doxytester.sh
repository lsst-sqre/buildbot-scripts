#! /bin/bash
#   T U N E     T H I S    T O     Y O U R    P R E F E R E N C E  
ANY_DIRECTORY=./AnyDirectory
#   T U N E     T H I S    T O     Y O U R    P R E F E R E N C E  

mkdir -p $ANY_DIRECTORY
cd $ANY_DIRECTORY
export LSST_HOME=/lsst/DC3/stacks/gcc445-RH6/28nov2011
export LSST_DEVEL=/lsst/home/buildbot/RHEL6//buildslaves/lsst-build1/SMBRG/sandbox
source $LSST_HOME/loadLSST.sh
rm -rf lsstDoxygen
git clone $LSST_DMS/devenv/lsstDoxygen.git lsstDoxygen
cd lsstDoxygen
setup -r .
eups list -s
scons 

# Now setup for build of Data Release library documentation
DATAREL_VERSION=`eups list datarel | grep "buildslave" | awk '{print $1}'`
echo "DATAREL_VERSION: $DATAREL_VERSION"
setup datarel $DATAREL_VERSION
echo "======================================================="
eups list -s
echo "======================================================="

./bin/makeDocs datarel $DATAREL_VERSION > MakeDocs.out
if [ $? != 0 ] ; then
    echo "FATAL: Failed to generate complete makeDocs output"
    exit 1
fi

doxygen MakeDocs.out

