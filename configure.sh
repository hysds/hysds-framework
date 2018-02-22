#!/bin/bash
BASE_PATH=$(dirname "${BASH_SOURCE}")
BASE_PATH=$(cd "${BASE_PATH}"; pwd)


# turn on extglob
shopt -s extglob


cmdname=$(basename $0)


echoerr() { echo "$@" 1>&2; }


usage() {
  cat << USAGE >&2
Usage:
    $cmdname
    -h | --help                 Print help
USAGE
  exit 1
}


# process arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      shift 1
      ;;
    *)
      echoerr "Unknown argument: $1"
      usage
    ;;
  esac
done


# source mozart virtualenv
source $HOME/mozart/bin/activate
if [ "$?" -ne 0 ]; then
  echoerr "Failed to source mozart environment. Check installation."
  exit 1
fi


# configure sds
sds configure
