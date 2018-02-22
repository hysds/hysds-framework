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


# copy cluster.py in ~/hsds_cluster_setup
FAB_FILE=$HOME/hysds_cluster_setup/cluster.py
if [ ! -e "$FAB_FILE" ]; then
  cp ${FAB_FILE}.example ${FAB_FILE}
fi


# prompt user to customize hysds_cluster_setup
echo "Your hysds_cluster_setup at $HOME/hysds_cluster_setup is ready."
echo ""
echo "You should:"
echo "- update $FAB_FILE with any customizations for your cluster"
echo "- update datasets.json* under $HOME/hysds_cluster_setup/files for your cluster"
echo "- ensure $HOME/hysds_cluster_setup/files/datasets.json exists"
echo ""
echo "Once done, you may proceed with running hysds_cluster_setup scripts like update.sh,"
echo "stop.sh, start.sh, reset.sh or start running fabric commands."
