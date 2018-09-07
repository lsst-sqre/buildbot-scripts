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
# * SKIP_DOCS
# * PREP_ONLY
#
# removed/fatal
# * SKIP_DEMO

if [[ -z ${SKIP_DEMO+x} ]]; then
  >&2 echo -e 'SKIP_DEMO is not supported'
  exit 1
fi

BRANCH=${BRANCH:-''}
PRODUCT=${PRODUCT:-lsst_distrib lsst_ci}
deploy=${deploy:-''}
LSST_COMPILER=${LSST_COMPILER?LSST_COMPILER is required}
LSST_PYTHON_VERSION=${LSST_PYTHON_VERSION?LSST_PYTHON_VERSION is required}

NO_FETCH=${NO_FETCH:-false}
SKIP_DOCS=${SKIP_DOCS:-false}
PREP_ONLY=${PREP_ONLY:-false}

ARGS=()

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

if [[ $NO_FETCH == true ]]; then
  ARGS+=('--no-fetch')
fi
if [[ $PREP_ONLY == true ]]; then
  ARGS+=('--prepare-only')
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
