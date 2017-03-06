#!/bin/bash -e

# This script is a thin wrapper around `lsstswBuild.sh` and is only intended to
# be useful when executed by jenkins.  It assumes that the `lsst/lsstsw` and
# `lsst-sqre/buildbot-script` repos have already been cloned into the jenkins
# `$WORKSPACE`.

# The following environment variables are assumed to be declared by the caller:
#
# * BRANCH
# * BUILD_NUMBER
# * deploy
# * NO_FETCH
# * PRODUCT
# * python
# * SKIP_DEMO
# * SKIP_DOCS
#

ARGS=()

# append lsst_ci to PRODUCT list unless SKIP_DEMO is set
if [[ $SKIP_DEMO != "true" ]]; then
  if [[ -z "$PRODUCT" ]]; then
    # lsstsw default targets
    PRODUCT="lsst_distrib qserv_distrib dax_webserv"
  fi
  PRODUCT="$PRODUCT lsst_ci"
fi

if [[ ! -z "$BRANCH" ]]; then
  ARGS+=('--branch')
  ARGS+=("$BRANCH")
fi

ARGS+=('--build_number')
ARGS+=("$BUILD_NUMBER")

if [[ ! -z "$PRODUCT" ]]; then
  ARGS+=('--product')
  ARGS+=("$PRODUCT")
fi

if [[ $SKIP_DOCS == "true" ]]; then
  ARGS+=('--skip_docs')
fi

ARGS+=('--print-fail')
ARGS+=('--color')

if [[ $SKIP_DEMO == "true" ]]; then
  ARGS+=('--skip_demo')
fi

if [[ $NO_FETCH == "true" ]]; then
  ARGS+=('--no-fetch')
fi

set -o verbose
if grep -q -i "CentOS release 6" /etc/redhat-release 2>/dev/null; then
  . /opt/rh/devtoolset-3/enable
fi
set +o verbose

export LSSTSW=${LSSTSW:-$WORKSPACE/lsstsw}


case $(uname -s) in
  Darwin*)
    if ! hash gfortran; then
      echo "gfortran is required but missing"
      # gfortran is part of the gcc bottle
      brew install gcc
    fi
    ;;
esac

(
  cd "$LSSTSW"

  OPTS=()

  # shellcheck disable=SC2154
  if [[ "$python" == "py3" ]]; then
    OPTS+=('-3')
  fi

  # shellcheck disable=SC2154
  if [[ $deploy == "bleed" ]]; then
    OPTS+=('-b')
  fi

  ./bin/deploy "${OPTS[@]}"
)

"$(cd "$(dirname "$0")"; pwd)/lsstswBuild.sh" "${ARGS[@]}"
