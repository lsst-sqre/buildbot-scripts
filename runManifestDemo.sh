#! /bin/bash
# Run the demo code to test DM algorithms

set -e

# https://github.com/lsst/lsst_dm_stack_demo/archive/master.tar.gz
DEMO_BASE_URL=${DEMO_BASE_URL:-https://github.com/lsst/lsst_dm_stack_demo/archive}
# lsst_dm_stack_demo-master.tar.gz
DEMO_BASE_DIR=${DEMO_BASE_DIR:-lsst_dm_stack_demo}

print_error() {
  >&2 echo -e "$@"
}

fail() {
  local code=${2:-1}
  [[ -n $1 ]] && print_error "$1"
  # shellcheck disable=SC2086
  exit $code
}

setup() {
  # eval masks all errors
  if ! type -p eups_setup; then
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
  if curl -Ls --fail --head -o /dev/null "$url"; then
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

# shellcheck disable=SC2034
options=$(getopt -l help,small,tag: -- "$@")
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
    --)
        break
        ;;
    *)
        [[ "$*" != "" ]] && usage
        break
        ;;
  esac
done

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

curl "$CURL_OPTS" -L -o "$DEMO_TGZ" "$DEMO_URL"
if [[ ! -f $DEMO_TGZ ]]; then
  fail "*** Failed to acquire demo from: ${DEMO_URL}."
fi

echo "tar xzf ${DEMO_TGZ}"
if ! tar xzf "$DEMO_TGZ"; then
  fail "*** Failed to unpack: ${DEMO_TGZ}"
fi

if [[ ! -d $DEMO_DIR ]]; then
  fail "*** Failed to find unpacked directory: ${DEMO_DIR}"
fi

cd "$DEMO_DIR"

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

#*************************************************************************
cat <<-EOF
----------------------------------------------------------------
EUPS-tag: ${TAG}     Version: ${VERSION}
Dataset size: ${SIZE}
Current $(umask -p)
Setup lsst_apps
$(eups list  -s)
-----------------------------------------------------------------
EOF

if [[ -z $PIPE_TASKS_DIR || -z $OBS_SDSS_DIR ]]; then
  fail "*** Failed to setup either PIPE_TASKS or OBS_SDSS; both of which are required by ${DEMO_DIR}"
fi

if ! ./bin/demo.sh --$SIZE; then
  fail "*** Failed during execution of ${DEMO_DIR}"
fi

# Add column position to each label for ease of reading the output comparison
COLUMNS=$(head -1 detected-sources$SIZE_EXT.txt| sed -e "s/^#//")
j=1
NEWCOLUMNS=$(for i in $COLUMNS; do echo -n "$j:$i "; j=$((j+1)); done)
cat <<-EOF
Columns in benchmark datafile:
${NEWCOLUMNS}
./bin/compare detected-sources${SIZE_EXT}.txt
EOF

if ! ./bin/compare detected-sources${SIZE_EXT}.txt; then
  fail "*** Warning: output results not within error tolerance for: ${DEMO_DIR}"
fi

# vim: tabstop=2 shiftwidth=2 expandtab
