#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
# shellcheck source=./ccutils.sh
source "${SCRIPT_DIR}/ccutils.sh"

set -xeo pipefail

# This script is a thin wrapper around `lsstswBuild.sh` and is only intended to
# be useful when executed by jenkins.  It assumes that the `lsst/lsstsw` and
# `lsst-sqre/buildbot-script` repos have already been cloned into the jenkins
# `$WORKSPACE`.

# The following environment variables are assumed to be declared by the caller:
#
# * LSST_COMPILER
# * LSST_PYTHON_VERSION
#
# optional:
#
# * BRANCH
# * deploy
# * PRODUCT
# * NO_FETCH
# * SKIP_DEMO
# * SKIP_DOCS
# * PREP_ONLY
#

BRANCH=${BRANCH:-''}
deploy=${deploy:-''}
PRODUCT=${PRODUCT:-''}
LSST_COMPILER=${LSST_COMPILER?LSST_COMPILER is required}
LSST_PYTHON_VERSION=${LSST_PYTHON_VERSION?LSST_PYTHON_VERSION is required}

NO_FETCH=${NO_FETCH:-false}
SKIP_DEMO=${SKIP_DEMO:-false}
SKIP_DOCS=${SKIP_DOCS:-false}
PREP_ONLY=${PREP_ONLY:-false}

ARGS=()

# append lsst_ci to PRODUCT list unless SKIP_DEMO is set
if [[ $SKIP_DEMO != true ]]; then
  if [[ -z $PRODUCT ]]; then
    # lsstsw default targets
    PRODUCT="lsst_distrib qserv_distrib dax_webserv"
  fi
  PRODUCT="$PRODUCT lsst_ci"
fi

if [[ ! -z $BRANCH ]]; then
  ARGS+=('--branch')
  ARGS+=("$BRANCH")
fi

if [[ ! -z $PRODUCT ]]; then
  ARGS+=('--product')
  ARGS+=("$PRODUCT")
fi

if [[ $SKIP_DOCS == true ]]; then
  ARGS+=('--skip_docs')
fi

ARGS+=('--color')

if [[ $SKIP_DEMO == true ]]; then
  ARGS+=('--skip_demo')
fi

if [[ $NO_FETCH == true ]]; then
  ARGS+=('--no-fetch')
fi
if [[ $PREP_ONLY == true ]]; then
  ARGS+=('--prepare-only')
fi

# require that $LSST_COMPILER is defined
if [[ -z $LSST_COMPILER ]]; then
  >&2 echo -e 'LSST_COMPILER is not defined'
  exit 1
fi

cc::setup_first "$LSST_COMPILER"

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

# configure [mini]conda installer/package mirrors *before* deploy is run
#
# XXX this is a temporary kludge to work around freestyle/matrix jobs being
# unable to access injected credentials env vars from inside an
# environmentVariables block.
if [[ -n $CMIRROR_S3_BUCKET ]]; then
  export CONDA_CHANNELS="http://${CMIRROR_S3_BUCKET}/pkgs/free"
  export MINICONDA_BASE_URL="http://${CMIRROR_S3_BUCKET}/miniconda"
fi

(
  cd "$LSSTSW"

  OPTS=()

  if [[ -n ${LSST_PYTHON_VERSION+1} ]]; then
    case $LSST_PYTHON_VERSION in
      2)
        OPTS+=('-2')
        ;;
      3)
        OPTS+=('-3')
        ;;
      *)
        >&2 echo "unsupported python version: $LSST_PYTHON_VERSION"
        exit 1
        ;;
    esac
  fi

  # shellcheck disable=SC2154
  if [[ $deploy == bleed ]]; then
    OPTS+=('-b')
  fi

  ./bin/deploy "${OPTS[@]}"
)

"${SCRIPT_DIR}/lsstswBuild.sh" "${ARGS[@]}"

# vim: tabstop=2 shiftwidth=2 expandtab
