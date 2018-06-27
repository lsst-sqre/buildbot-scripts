#!/bin/bash

set -e

cc::print_error() {
  >&2 echo -e "$@"
}

cc::fail() {
  local code=${2:-1}
  [[ -n $1 ]] && cc::print_error "$1"
  # shellcheck disable=SC2086
  exit $code
}

cc::check_cc_path() {
  local cc_path=${1?cc_path is required}

  if [[ -z $cc_path ]]; then
    cc::fail "compiler appears to be missing from PATH"
  fi
}

cc::check_sys_cc() {
  local cc_path=${1?cc_path is required}
  local sys_cc_path=${1?sys_cc_path is required}

  if [[ $cc_path != "$sys_cc_path" ]]; then
    cc::fail "system compiler is not default"
  fi
}

cc::check_scl_collection() {
  local collection=${1?collection is required}

  scl --list | grep --quiet "$collection"
}

# source "quietly", ignoring -o xtrace
cc::scl_source() {
  local scl=${1?scl is required}

  # XXX scl_source seems to be broken on el6 as `/usr/bin/scl_enabled
  # devtoolset-3` is always exiting 1. Directly sourcing the enable script
  # seem to work across el6/7.
  # source scl_source enable "$compiler"
  # shellcheck disable=SC1090
  source "/opt/rh/${scl}/enable"
}

# Ensure that the desired cc will be in use either by managling the env to
# configure that compiler as the "default" or by verifying that it is already
# the default CC
#
# Beware possibly deep side effects...
cc::setup() {
  local compiler=${1?compiler string is required}

  case $compiler in
    devtoolset-*):
      cc::check_scl_collection "$compiler"
      cc::scl_source "$compiler"
      ;;
    llvm-toolset-*):
      cc::check_scl_collection "$compiler"
      cc::scl_source "$compiler"

      # eupspkg.sh passes $CC to scons as cc=$CC -- this needs to be "clang"
      # without a path prefix.  sconsUtils ignores these env vars.
      export CC=clang
      export CXX=clang++
      # needed to force distutils to *not* use the same compiler as python was
      # built with
      # see: https://bugs.python.org/issue24935
      export LDSHARED="${CC} -shared"
      ;;
    gcc-system)
      set +e
      cc_path=$(type -p gcc)
      set -e
      sys_cc_path='/usr/bin/gcc'

      cc::check_cc_path "$cc_path"
      cc::check_sys_cc "$cc_path" "$sys_cc_path"
      ;;
    clang* | ^clang*)
      set +e
      cc_path=$(type -p clang)
      set -e
      sys_cc_path='/usr/bin/clang'

      cc::check_cc_path "$cc_path"
      cc::check_sys_cc "$cc_path" "$sys_cc_path"

      # Apple LLVM version 8.0.0 (clang-800.0.42.1)
      # XXX note that this is apple-clang specific -- will not work with
      # llvm/clang on other platforms
      if [[ ! $(clang --version) =~ Apple[[:space:]]+LLVM[[:space:]]+version[[:space:]]+[[:digit:].]+[[:space:]]+\((.*)\) ]]; then
        cc::fail "unable to determine compiler version"
      fi
      cc_version="${BASH_REMATCH[1]}"

      if [[ ! $cc_version =~ $compiler ]]; then
        cc::fail "found clang $cc_version but expected $compiler"
      fi
      ;;
    *)
      cc::fail "lp is on fire!"
      ;;
  esac
}

# Accept/setup the first compiler, starting from the left hand side, of the
# space seperated list of compiler strings.  Note that this is intentionally
# accepting a single argument which is split on whitespace.
cc::setup_first() {
  local compilers=${1?compilers string is required}

  IFS=" " read -r -a candidates <<< "$compilers"
  # this... intersting expression is required to work with bash < 4.2 -- thank
  # you OSX
  local last=${candidates[${#candidates[@]}-1]}

  for cc in "${candidates[@]}"; do
    if [[ $cc == "$last" ]]; then
      # allow stdout/stderr/exit output from final canidate
      cc::setup "$cc"
    else
      set +e
      # block stdout/stderr/exit from candiates that may fail
      # using a subshell to ignore exit
      if (cc::setup "$cc" > /dev/null 2>&1); then
        break
      fi
      set -e
    fi
  done
}

# vim: tabstop=2 shiftwidth=2 expandtab
