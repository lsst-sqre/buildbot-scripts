#!/bin/bash -e
#  Install the DM code stack using the lsstsw package procedure: rebuild

# /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\
#  This script modifies the actual DM stack on the cluster. It therefore
#  explicitly checks literal strings to ensure that non-standard buildbot
#  expectations regarding the 'work' directory location are  equivalent.
# /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
source "${SCRIPT_DIR}/settings.cfg.sh"
source "${LSSTSW}/bin/setup.sh"

# Reuse an existing lsstsw installation
BUILD_NUMBER="0"
BUILD_DOCS="yes"
RUN_DEMO="yes"
PRODUCT=""
NO_FETCH=0
PRINT_FAIL=0
COLORIZE=0

# Buildbot remotely invokes scripts with a stripped down environment.
umask 002

sbar=$(printf %78s |tr " " "-")
tbar=$(printf %78s |tr " " "~")

set_color() {
    if [ $COLORIZE -eq 1 ]; then
        echo -ne "$@"
    fi
}

no_color() {
    if [ $COLORIZE -eq 1 ]; then
        echo -ne "$NO_COLOR"
    fi
}

print_success() {
    set_color "$LIGHT_GREEN"
    echo -e "$@"
    no_color
}

print_info() {
    set_color "$YELLOW"
    echo -e "$@"
    no_color
}

# XXX this script is very inconsistent about what is sent to stdout vs stderr
print_error() {
    set_color "$LIGHT_RED"
    >&2 echo -e "$@"
    no_color
}

start_section() {
    print_info "### $*"
    print_info "$tbar"
}

end_section() {
    print_info "$sbar"
    echo -ne "\n"
}

print_log_file() {
    local pkg=$1
    local log=$2
    local basename=${log##*/}

    start_section "$pkg - $basename"
    echo -e "$(<"$log")"
    end_section
}

print_build_failure() {
    for pkg in "${PACKAGES[@]}"; do
        local build_dir=${LSSTSW_BUILD_DIR}/${pkg}
        local build_log=${build_dir}/_build.log
        local test_dir=${build_dir}/tests/.tests
        local config_log=${build_dir}/config.log

        # check to see if build log exists
        if [ ! -e "$build_log" ]; then
            # no log means that package was not [attempted] to be be built
            # on this run
            continue
        fi

        # print the build log if it contains any "error"s
        local build_error=false
        if grep -q -i error "$build_log"; then
            build_error=true
        fi

        # check to see if package had any failed tests
        local test_error=false
        shopt -s nullglob
        local failed_tests=(${test_dir}/*.failed)
        if [ ${#failed_tests[@]} -ne 0 ]; then
            test_error=true
        fi

        local log_files=() # array of logs to print

        # if any errors were detected for this package...
        if [[ "$build_error" == true || "$test_error" == true ]]; then
            # print _build.log
            log_files=("${log_files[@]}" "$build_log")

            # print config.log (if it exists)
            if [ -e "$config_log" ]; then
                log_files=("${log_files[@]}" "$config_log")
            fi
        fi

        # and print any failed tests
        if [[ "$test_error" == true ]]; then
            log_files=("${log_files[@]}" "${failed_tests[@]}")
        fi

        if [ ${#log_files[@]} -ne 0 ]; then
            for log in "${log_files[@]}"; do
                print_log_file "$pkg" "$log"
            done
        fi
    done
}

# XXX REF_LIST and PRODUCT would be better handled as arrays
# shellcheck disable=SC2054 disable=SC2034
options=(getopt --long build_number:,branch:,product:,skip_docs,skip_demo,no-fetch,print-fail,color -- "$@")
while true
do
    case "$1" in
        --build_number) BUILD_NUMBER="$2" ; shift 2 ;;
        --branch)       BRANCH=$2         ; shift 2 ;;
        --product)      PRODUCT=$2        ; shift 2 ;;
        --skip_docs)    BUILD_DOCS="no"   ; shift 1 ;;
        --skip_demo)    RUN_DEMO="no"     ; shift 1 ;;
        --no-fetch)     NO_FETCH=1        ; shift 1 ;;
        --print-fail)   PRINT_FAIL=1      ; shift 1 ;;
        --color)        COLORIZE=1        ; shift 1 ;;
        --) shift ; break ;;
        *) [ "$*" != "" ] && print_error "Unknown option: $1" && exit "$BUILDBOT_FAILURE"
           break;;
    esac
done

# mangle whitespace and prepend ` -r ` in front of each ref
REF_LIST=$(echo "$BRANCH" | sed  -e "s/ \+ / /g" -e "s/^/ /" -e "s/ $//" -e "s/ / -r /g")


#
# display configuration
#
start_section "configuration"

# print "settings"
settings=(
    BRANCH
    BUILD_DOCS
    BUILD_NUMBER
    COLORIZE
    DEMO_ROOT
    DEMO_TGZ
    DOC_PUSH_PATH
    DOC_REPO_DIR
    DOC_REPO_NAME
    DOC_REPO_URL
    LSSTSW
    LSSTSW_BUILD_DIR
    NO_FETCH
    PRODUCT
    REF_LIST
    RUN_DEMO
)

set_color "$LIGHT_CYAN"
for i in ${settings[*]}
do
    eval echo "${i}: \$$i"
done
no_color

end_section # configuration


#
# display environment variables
#
start_section "environment"
set_color "$LIGHT_CYAN"
printenv
no_color
end_section # environment


#
# build with <lsstsw>/bin/rebuild
#
start_section "build"

if [ ! -x "${LSSTSW}/bin/rebuild" ]; then
     print_error "Failed to find 'rebuild'."
     exit "$BUILDBOT_FAILURE"
fi

print_info "Rebuild is commencing....stand by; using $REF_LIST"

ARGS=()
if [ $NO_FETCH -eq 1 ]; then
    ARGS+=("-n")
else
    ARGS+=("-u")
fi
if [[ ! -z "$REF_LIST" ]]; then
    # XXX intentionally not quoted to allow word splitting
    ARGS+=($REF_LIST)
fi
if [[ ! -z "$PRODUCT" ]]; then
    # XXX intentionally not quoted to allow word splitting
    ARGS+=($PRODUCT)
fi
set -e

BUILD_PREPARED=false
BUILD_SUCCESS=false

set +e
"${LSSTSW}/bin/rebuild" "${ARGS[@]}"
RET=$?
set -e

if [ $RET -eq 0 ]; then
    BUILD_PREPARED=true
    BUILD_SUCCESS=true
else
    if [[ $RET -gt 128 ]]; then
        BUILD_PREPARED=true
    fi
fi

if [[ $BUILD_PREPARED == true ]];then
    # manifest.txt generated by lsst_build
    MANIFEST=${LSSTSW_BUILD_DIR}/manifest.txt

    # array of eups packages extracted from manifest; this excludes any repos that
    # may be checked out but not part of the current build graph
    PACKAGES=($(tail -n+3 "$MANIFEST" | awk '{ print $1 }'))

    # Set current build tag (also used as eups tag per installed package).
    eval "$(grep -E '^BUILD=' "$MANIFEST" | sed -e 's/BUILD/TAG/')"
fi

if [[ $BUILD_SUCCESS == true ]]; then
    print_success "The DM stack has been installed at $LSSTSW with tag: $TAG."
else
    print_error "Failed during rebuild of DM stack."
fi

end_section # build


#
# process/display build failures
#
if [[ $BUILD_SUCCESS == false ]]; then
    if [[ $BUILD_PREPARED == true && $PRINT_FAIL -eq 1 ]]; then
        print_build_failure
    fi

    exit "$BUILDBOT_FAILURE"
fi


#
# Build doxygen documentation
#
if [ $BUILD_DOCS == "yes" ]; then
    start_section "doc build"

    print_info "Start Documentation build at: $(date)"
    set +e
    "${SCRIPT_DIR}/create_xlinkdocs.sh" --type "master" --path "$DOC_PUSH_PATH"
    RET=$?
    set -e

    if [ $RET -eq 2 ]; then
        print_error "*** Doxygen documentation returned with a warning."
        print_error "*** Review the Buildbot 'stdio' log for build: $BUILD_NUMBER."
        exit "$BUILDBOT_WARNING"
    elif [ $RET -ne 0 ]; then
        print_error "*** FAILURE: Doxygen document was not installed."
        print_error "*** Review the Buildbot 'stdio' log for build: $BUILD_NUMBER."
        exit "$BUILDBOT_FAILURE"
    fi
    print_success "Doxygen Documentation was installed successfully."

    end_section # doc build"
else
    print_info "Skipping Documentation build."
fi


#
# Finally run a simple test of package integration
#
if [ $RUN_DEMO == "yes" ]; then
    start_section "demo"

    print_info "Start Demo run at: $(date)"
    set +e
    "${SCRIPT_DIR}/runManifestDemo.sh" --tag "$TAG" --small
    RET=$?
    set -e

    if [ $RET -eq 2 ]; then
        print_error "*** The simple integration demo completed with some statistical deviation in the output comparison."
        exit "$BUILDBOT_WARNING"
    elif [ $RET -ne 0 ]; then
        print_error "*** There was an error running the simple integration demo."
        print_error "*** Review the Buildbot 'stdio' log for build: $BUILD_NUMBER."
        exit "$BUILDBOT_FAILURE"
    fi
    print_success "The simple integration demo was successfully run."

    end_section # demo
else
    print_info "Skipping Demo."
fi
