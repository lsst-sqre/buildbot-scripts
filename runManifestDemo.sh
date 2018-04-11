#!/bin/bash
# Run the demo code to test DM algorithms

set -e

# https://github.com/lsst/lsst_dm_stack_demo/archive/master.tar.gz
DEMO_BASE_URL=${DEMO_BASE_URL:-https://github.com/lsst/lsst_dm_stack_demo/archive}
# lsst_dm_stack_demo-master.tar.gz
DEMO_BASE_DIR=${DEMO_BASE_DIR:-lsst_dm_stack_demo}
# relative to the root of the demo archive
DEMO_RUN_SCRIPT='./bin/demo.sh'
DEMO_CMP_SCRIPT='./bin/compare'

print_error() {
  >&2 echo -e "$@"
}

fail() {
  local code=${2:-1}
  [[ -n $1 ]] && print_error "$1"
  # shellcheck disable=SC2086
  exit $code
}

has_cmd() {
  local command=${1?command is required}
  run command -v "$command" > /dev/null 2>&1
}

setup() {
  # eval masks all errors
  if ! has_cmd eups_setup; then
    fail "unable to find eups_setup"
  fi
  eval "$(eups_setup DYLD_LIBRARY_PATH="${DYLD_LIBRARY_PATH}" "$@")"
}

deeupsify_tag() {
  local eups_tag=${1?eups_tag parameter is required}

  # convert _ -> .
  git_tag=${eups_tag//_/.}

  # remove leading v
  git_tag=${git_tag#v}

  echo "$git_tag"
}

mk_archive_url() {
  local ref=${1?ref parameter is required}

  echo "${DEMO_BASE_URL}/${ref}.tar.gz"
}

mk_archive_dirname() {
  local ref=${1?ref parameter is required}

  echo "${DEMO_BASE_DIR}-${ref}"
}

mk_archive_filename() {
  local ref=${1?ref parameter is required}

  echo "$(mk_archive_dirname "$ref").tar.gz"
}

check_archive_ref() {
  local ref=${1?ref parameter is required}

  local url
  url=$(mk_archive_url "$ref")
  if run curl -Ls --fail --head -o /dev/null "$url"; then
    return 0
  fi

  return 1
}

find_archive_ref() {
  local tag=$1

  local ref
  local -a candidate_refs

  if [[ -n $tag ]]; then
    # shellcheck disable=SC2207
    candidate_refs=(
      "$tag"
      $(deeupsify_tag "$tag")
    )
  fi

  candidate_refs+=( master )

  for r in ${candidate_refs[*]}; do
    [[ -z $r ]] && continue
    if check_archive_ref "$r"; then
      ref=$r
      break
    fi
  done

  echo "$ref"
}

check_script() {
  local script=${1?command is required}

  [[ ! -e $script ]] && fail "*** script ${script} is missing"
  [[ ! -f $script ]] && fail "*** script ${script} is not a file"
  [[ ! -x $script ]] && fail "*** script ${script} is not executable"

  return 0
}

run() {
  if [[ $DRYRUN == true ]]; then
    echo "$@"
  elif [[ $DEBUG == true ]]; then
    (set -x; "$@")
  else
    "$@"
  fi
}

#--------------------------------------------------------------------------
# Standalone invocation for gcc master stack:
#--------------------------------------------------------------------------
# First: setup lsstsw stack
# cd $lsstsw/build
# ./runManifestDemo.sh --small
# or
# ./runManifestDemo.sh

#--------------------------------------------------------------------------
usage() {
  # note that heredocs are prefixed with tab chars
  fail "$(cat <<-EOF

		Usage: $0 [options]
		Initiate demonstration run.

		Options:
		 --tag <id> : eups-tag for eups-setup or defaults to latest master
		              build.
		 --small : to use small dataset; otherwise a mini-production size will
		           be used.

		EOF
  )"
}


TAG=""
SIZE=""
SIZE_EXT=""

if [[ -n "$*" ]]; then
  getopt -l help,small,debug,tag: -- "$@" > /dev/null 2>&1
  while true; do
    case $1 in
      --help)
        usage
        ;;
      --small)
        SIZE="small";
        SIZE_EXT="_small";
        shift 1
        ;;
      --tag)
        TAG=$2;
        shift 2
        ;;
      --debug)
        DEBUG=true;
        shift 1
        ;;
      --)
        break
        ;;
      *)
        [[ "$*" != "" ]] && usage
        break
        ;;
    esac
  done
fi

REF=$(find_archive_ref "$TAG")
DEMO_TGZ=$(mk_archive_filename "$REF")
DEMO_URL=$(mk_archive_url "$REF")
DEMO_DIR=$(mk_archive_dirname "$REF")

# disable curl progress meter unless running under a tty -- this is intended to
# reduce the amount of console output when running under CI
CURL_OPTS='-#'
if [[ ! -t 1 ]]; then
  CURL_OPTS='-sS'
fi

run curl "$CURL_OPTS" -L -o "$DEMO_TGZ" "$DEMO_URL"
if [[ ! -f $DEMO_TGZ ]]; then
  fail "*** Failed to acquire demo from: ${DEMO_URL}."
fi

if [[ -e $DEMO_DIR ]]; then
  {
		cat <<-EOF
		The demo archive destination path ${DEMO_DIR} already exists; attempting to
		remove it.
		EOF
  } | fmt -uw 78
  run rm -rf "$DEMO_DIR"
fi

if ! run tar xzf "$DEMO_TGZ"; then
  fail "*** Failed to unpack: ${DEMO_TGZ}"
fi

if [[ ! -d $DEMO_DIR ]]; then
  fail "*** Failed to find unpacked directory: ${DEMO_DIR}"
fi

# Setup either requested tag or last successfully built lsst_apps
if [[ -n $TAG ]]; then
  setup -t "$TAG" lsst_apps
else
  setup -j lsst_apps
  # only change pwd in a subshell
  VERSION="$(set -e
    cd "${LSST_APPS_DIR}/../"
    find . | sort -r -n -t+ +1 -2 | head -1
  )"
  setup lsst_apps "$VERSION"
fi

if [[ -z $PIPE_TASKS_DIR || -z $OBS_SDSS_DIR ]]; then
  fail "*** Failed to setup either PIPE_TASKS or OBS_SDSS; both of which are required by ${DEMO_DIR}"
fi

cd "$DEMO_DIR"

check_script "$DEMO_RUN_SCRIPT"
check_script "$DEMO_CMP_SCRIPT"

cat <<-EOF
----------------------------------------------------------------
EUPS-tag: ${TAG}
Version: ${VERSION}
Dataset size: ${SIZE}
Current $(umask -p)
[DEMO]REF: ${REF}
DEMO_TGZ: ${DEMO_TGZ}
DEMO_URL: ${DEMO_URL}
DEMO_DIR: ${DEMO_DIR}
PWD: ${PWD}
Setup lsst_apps
$(eups list  -s)
-----------------------------------------------------------------
EOF

if ! run "$DEMO_RUN_SCRIPT" --$SIZE; then
  fail "*** Failed during execution of ${DEMO_DIR}"
fi

# Add column position to each label for ease of reading the output comparison
COLUMNS=$(run head -1 detected-sources$SIZE_EXT.txt| sed -e "s/^#//")
j=1
NEWCOLUMNS=$(for i in $COLUMNS; do echo -n "$j:$i "; j=$((j+1)); done)
cat <<-EOF
Columns in benchmark datafile:
${NEWCOLUMNS}
EOF

if ! run "$DEMO_CMP_SCRIPT" detected-sources${SIZE_EXT}.txt; then
  fail "*** Warning: output results not within error tolerance"
fi

# vim: tabstop=2 shiftwidth=2 expandtab
