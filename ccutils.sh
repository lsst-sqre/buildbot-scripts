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

      # force verbose for enable script so we know something happened
      local opts
      opts=$(set +o)
      set -o verbose

      # XXX scl_source seems to be broken on el6 as `/usr/bin/scl_enabled
      # devtoolset-3` is always exiting 1. Directly sourcing the enable script
      # seem to work across el6/7.
      # source scl_source enable "$compiler"
      # shellcheck disable=SC1090
      source "/opt/rh/${compiler}/enable"

      # suppress verbose for eval
      set +o verbose
      ;;
    gcc-system)
      cc_path=$(type -p gcc)
      sys_cc_path='/usr/bin/gcc'

      cc::check_cc_path "$cc_path"
      cc::check_sys_cc "$cc_path" "$sys_cc_path"
      ;;
    clang-*)
      cc_path=$(type -p clang)
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

      if [[ $cc_version != "$compiler" ]]; then
        cc::fail "found clang $cc_version but expected $compiler"
      fi
      ;;
    *)
      cc::fail "lp is on fire!"
      ;;
  esac
}

# vim: tabstop=2 shiftwidth=2 expandtab
