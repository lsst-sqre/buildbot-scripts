#! /bin/bash

# Build cross linked doxygen documents and load into directory hierarchy
# intended to be exposed via a web-server.

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
source "${SCRIPT_DIR}/settings.cfg.sh"
source "${LSSTSW}/bin/setup.sh"

usage() {
    echo "Usage: $0 --type <type> --path <doxy docs path>"
    echo "Build crosslinked doxygen documentation and install on LSST website."
    echo "             type: either <git-branch>,  \"stable\", or \"beta\""
    echo "             path: actual path to the publicly accessible DM doxygen documentation"
    echo "Example: $0 --type master --path /home/foo/public_html/doxygen"
    echo "Example: $0 --type Winter2012 ---path /home/foo/public_html/doxygen"
    echo "Example: $0 --type stable --path /home/foo/public_html/doxygen"
    exit "$BUILDBOT_FAILURE"
}

# shellcheck disable=SC2034 disable=SC2054
options=(getopt --long type:,path: -- "$@")
while true
do
    case "$1" in
        --type) DOXY_TYPE="$2";   shift 2 ;;
        --path) INSTALL_ROOT="$2"; shift 2 ;;
        --) shift ; break ;;
        *) [ "$*" != "" ] && echo "Parsed options; arguments left are:$*:" && exit "$BUILDBOT_FAILURE"
            break;;
    esac
done

if [ -z "$DOXY_TYPE" -o -z "$INSTALL_ROOT" ]; then
    echo "***  Missing a required input parameter."
    usage
    exit "$BUILDBOT_FAILURE"
fi

DATE="$(date +%Y)_$(date +%m)_$(date +%d)_$(date +%H.%M.%S)"

# Normative doxy_type needs to be one of {normative(<branch>), beta, stable}
#   but doxy_type for master branch will now change to the tag name used
#   for a master build
NORMATIVE_DOXY_TYPE=$(echo "$DOXY_TYPE" | tr  "/" "_")
if [ "$DOXY_TYPE" == "master" ]; then
    eval "$(grep -E '^BUILD=' "$LSSTSW_BUILD_DIR"/manifest.txt)"
    echo "BUILD: $BUILD"
    if [ -z "$BUILD" ]; then
        echo "*** Failed: to determine most recent master build number."
        exit "$BUILDBOT_FAILURE"
    else
        DOXY_TYPE=$BUILD
    fi
fi

SYM_LINK_NAME="x_${NORMATIVE_DOXY_TYPE}DoxyDoc"
SYM_LINK_PATH="${INSTALL_ROOT}/${SYM_LINK_NAME}"
DOC_NAME="xlink_${NORMATIVE_DOXY_TYPE}_$DATE"
DOC_INSTALL_DIR="${INSTALL_ROOT}/${DOC_NAME}"
HTML_DIR="${DOC_REPO_DIR}/doc/html"

# print "settings"
settings=(
    DATE
    DOC_INSTALL_DIR
    DOC_NAME
    DOC_REPO_DIR
    DOC_REPO_URL
    DOXY_TYPE
    HTML_DIR
    INSTALL_ROOT
    LSSTSW_BUILD_DIR
    NORMATIVE_DOXY_TYPE
    SYM_LINK_NAME
    SYM_LINK_PATH
)

for i in ${settings[*]}
do
    eval echo "${i}: \$$i"
done

(
    set -e

    # Ensure fresh extraction
    rm -rf "$DOC_REPO_DIR"

    # SCM clone lsstDoxygen ** from master **
    git clone "$DOC_REPO_URL" "$DOC_REPO_DIR"
)
if [ $? != 0 ]; then
    echo "*** Failed to clone '$DOC_REPO_URL'."
    exit "$BUILDBOT_FAILURE"
fi

# setup all packages required by lsstDoxygen's eups
cd "$DOC_REPO_DIR"
# XXX can not run setup in a subshell for error handling
setup -t "$DOXY_TYPE" -r .
eups list -s

# Create doxygen docs for ALL setup packages; following is magic environment var
export xlinkdoxy=1

scons
if [  $? != 0 ]; then
    echo "*** Failed to build lsstDoxygen package."
    exit "$BUILDBOT_FAILURE"
fi

# Now setup for build of Data Release library documentation
DATAREL_VERSION=$(eups list -t "$DOXY_TYPE" datarel | awk '{print $1}')
if [ -z "$DATAREL_VERSION" ]; then
    echo "*** Failed to find datarel \"$DOXY_TYPE\" version."
    exit "$BUILDBOT_FAILURE"
fi
echo "DATAREL_VERSION: $DATAREL_VERSION"

# XXX can not run setup in a subshell for error handling
setup datarel "$DATAREL_VERSION"
eups list -s

"${DOC_REPO_DIR}/bin/makeDocs" --nodot --htmlDir "$HTML_DIR" datarel "$DATAREL_VERSION" > MakeDocs.out
if [ $? != 0 ] ; then
    echo "*** Failed to generate complete makeDocs output for \"$DOXY_TYPE\" source."
    exit "$BUILDBOT_FAILURE"
fi

doxygen MakeDocs.out
if [ $? != 0 ] ; then
    echo "*** Failed to generate doxygen documentation for \"$DOXY_TYPE\" source."
    exit "$BUILDBOT_FAILURE"
fi

# install built doxygen

(
    set -e

    mkdir -p "$INSTALL_ROOT"
    chmod o+rx "$INSTALL_ROOT"
)
if [ $? != 0 ]; then
    echo "*** Failed to prepare install root: ${INSTALL_ROOT}"
    exit "$BUILDBOT_FAILURE"
fi

(
    set -e

    cp -ar "$HTML_DIR" "$DOC_INSTALL_DIR"
    chmod o+rx "$DOC_INSTALL_DIR"
)
if [ $? != 0 ]; then
    echo "*** Failed to copy doxygen documentation to ${DOC_INSTALL_DIR}"
    exit "$BUILDBOT_FAILURE"
fi
echo "INFO: Doxygen documentation copied to \"$DOC_INSTALL_DIR\""

# symlink the default xlinkdoxy name to new directory.
ln -snf "$DOC_INSTALL_DIR" "$SYM_LINK_PATH"
if [ $? != 0 ]; then
    echo "*** Failed to symlink: \"$SYM_LINK_PATH\", to new doxygen documentation: \"$DOC_INSTALL_DIR\""
    exit "$BUILDBOT_FAILURE"
fi
echo "INFO: Updated symlink: \"$SYM_LINK_PATH\", to point to new doxygen documentation: $DOC_INSTALL_DIR."
