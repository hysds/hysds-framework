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
    $cmdname <component>
    -r RELEASE | --release=RELEASE
                                Release tag to use for installation; without this option specified, a list
                                of releases will be printed and the installation stops
    -h | --help                 Print help
    -t | --test                 Install test HySDS component, e.g. $HOME/mozart-test instead of $HOME/mozart
    COMPONENT                   <component>: mozart | grq | metrics | verdi
USAGE
  exit 1
}


link_repo() {
  cd $1
  PACKAGE=$2
  PACKAGE_DIR=${PACKAGE}-*
  ln -sf $PACKAGE_DIR $PACKAGE
}


install_repo() {
  cd $1
  PACKAGE=$2
  PACKAGE_DIR=${PACKAGE}-*
  link_repo $1 $2
  cd $OPS/$PACKAGE
  pip install -e .
  if [ "$?" -ne 0 ]; then
    echo "Failed to run 'pip install -e .' for $PACKAGE."
    exit 1
  fi
}


# process arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      shift 1
      ;;
    --test|-t)
      DIR_POST="-test"
      shift 1
      ;;
    -r)
      RELEASE="$2"
      if [[ $RELEASE == "" ]]; then break; fi
      shift 2
      ;;
    --release=*)
      RELEASE="${1#*=}"
      shift 1
      ;;
    mozart|metrics|verdi)
      COMPONENT="$1"
      HYSDS_DIR="$1"
      shift 1
      ;;
    grq)
      COMPONENT="$1"
      HYSDS_DIR="sciflo"
      shift 1
      ;;
    *)
      echoerr "Unknown argument: $1"
      usage
    ;;
  esac
done


# check component is defined
if [[ "$COMPONENT" == "" ]]; then
  echoerr "Error: you need to provide the HySDS component."
  usage
fi


# installation dir for HySDS
INSTALL_DIR=$HOME/${HYSDS_DIR}${DIR_POST}
echo "HySDS install directory set to $INSTALL_DIR"


# create virtualenv if not found
if [ ! -e "$INSTALL_DIR/bin/activate" ]; then
  virtualenv --system-site-packages $INSTALL_DIR
  echo "Created virtualenv at $INSTALL_DIR."
fi


# source virtualenv
source $INSTALL_DIR/bin/activate


# install latest pip and setuptools
pip install -U pip
pip install -U setuptools


# force install supervisor
if [ ! -e "$INSTALL_DIR/bin/supervisord" ]; then
  pip install --ignore-installed supervisor
fi


# create etc directory
if [ ! -d "$INSTALL_DIR/etc" ]; then
  mkdir $INSTALL_DIR/etc
fi


# create log directory
if [ ! -d "$INSTALL_DIR/log" ]; then
  mkdir $INSTALL_DIR/log
fi


# create run directory
if [ ! -d "$INSTALL_DIR/run" ]; then
  mkdir $INSTALL_DIR/run
fi


# set github API urls
GIT_URL="https://github.com"
API_URL="https://api.github.com"


# set hysds-framework API url
REL_API_URL="${API_URL}/repos/hysds/hysds-framework/releases"


# get all releases
declare -A rels
for i in `${BASE_PATH}/query_releases.py $REL_API_URL`; do
  rel_id=`echo $i | awk 'BEGIN{FS="|"}{print $1}'`
  rel_tag=`echo $i | awk 'BEGIN{FS="|"}{print $2}'`
  rels[$rel_tag]+=$rel_id
done


# print release if not specified
if [[ "$RELEASE" == "" ]]; then
  echo "No release specified. Use -r RELEASE | --release=RELEASE to install a specific release. Listing available releases:"
  for tag in "${!rels[@]}"; do
    echo "$tag"
  done | sort
  exit 0
fi


# verify release exists
if [[ "${rels[$RELEASE]}" == "" ]]; then
  echoerr "Error: release $RELEASE doesn't exist."
  usage
fi


# create ops directory
OPS="$INSTALL_DIR/ops"
if [ ! -d "$OPS" ]; then
  mkdir $OPS
fi
cd $OPS


# download all assets for a release and untar
declare -A assets
for i in `${BASE_PATH}/query_releases.py $REL_API_URL -r $RELEASE`; do
  as_name=`echo $i | awk 'BEGIN{FS="|"}{print $1}'`
  as_url=`echo $i | awk 'BEGIN{FS="|"}{print $2}'`
  assets[$as_name]+=$as_url
  wget --header="Accept: application/octet-stream" -O $as_name $as_url
  tar xvfz $as_name
done
rm -rf *.tar.gz


# export latest prov_es package
install_repo $OPS prov_es


# export latest osaka package
pip install -U python-dateutil
install_repo $OPS osaka


# export latest hysds_commons package
install_repo $OPS hysds_commons


# export latest hysds package
cd $OPS
PACKAGE=hysds
PACKAGE_DIR=${PACKAGE}-!(dockerfiles*)
ln -sf $PACKAGE_DIR $PACKAGE
pip install -U  greenlet
pip install -U  pytz
pip uninstall -y celery
cd $OPS/$PACKAGE/third_party/celery-v3.1.25.pqueue
pip install --process-dependency-links -e .
cd $OPS/$PACKAGE
pip install --process-dependency-links -e .
if [ "$?" -ne 0 ]; then
  echo "Failed to run 'pip install -e .' for $PACKAGE."
  exit 1
fi


# export latest sciflo package
install_repo $OPS sciflo


# export latest mozart package
install_repo $OPS mozart


# export latest figaro package
install_repo $OPS figaro


# export latest grq2 package
link_repo $OPS grq2


# export latest tosca package
link_repo $OPS tosca


# export latest spyddder-man package
link_repo $OPS spyddder-man


# export latest lightweight-jobs package
link_repo $OPS lightweight-jobs


# export latest container-builder package
link_repo $OPS container-builder


# export latest s3-bucket-listing package
link_repo $OPS s3-bucket-listing


# export latest hysds-dockerfiles package
link_repo $OPS hysds-dockerfiles
