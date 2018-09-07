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
# * REFS
# * PRODUCTS
# * deploy
# * NO_FETCH
# * SKIP_DOCS
# * PREP_ONLY
#
# removed/fatal
# * BRANCH
# * PRODUCT
# * SKIP_DEMO

LSST_COMPILER=${LSST_COMPILER?LSST_COMPILER is required}
LSST_PYTHON_VERSION=${LSST_PYTHON_VERSION?LSST_PYTHON_VERSION is required}

REFS=${REFS:-''}
PRODUCTS=${PRODUCTS:-lsst_distrib lsst_ci}
deploy=${deploy:-''}
NO_FETCH=${NO_FETCH:-false}
SKIP_DOCS=${SKIP_DOCS:-false}
PREP_ONLY=${PREP_ONLY:-false}

fatal_vars() {
  local problems=(
    BRANCH
    PRODUCT
    SKIP_DEMO
  )
  local found=()

  for v in ${problems[*]}; do
    if [[ -n ${!v+1} ]]; then
      found+=("$v")
      >&2 echo -e "${v} is not supported"
    fi
  done

  [[ ${#found[@]} -ne 0 ]] && exit 1
  return 0
}
fatal_vars

ARGS=()
ARGS+=('--color')

[[ -n $REFS ]] &&  ARGS+=('--refs' "$REFS")
[[ -n $PRODUCTS ]] && ARGS+=('--products' "$PRODUCTS")

[[ $SKIP_DOCS == true ]] && ARGS+=('--skip_docs')
[[ $NO_FETCH == true ]] &&  ARGS+=('--no-fetch')
[[ $PREP_ONLY == true ]] && ARGS+=('--prepare-only')

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
