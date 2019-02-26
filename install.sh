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
    -d | --dev
                                Development mode installation; install master branch of all repos instead
                                of official releases
    -r RELEASE | --release=RELEASE
                                Release tag to use for installation; without this option specified, a list
                                of releases will be printed and the installation stops
    -k GIT_OAUTH_TOKEN | --token=GIT_OAUTH_TOKEN
                                OAuth token to use to authenticate
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


clone_dev_repo() {
  cd $1
  PACKAGE=$2
  GIT_URL=$3
  BRANCH=$4
  if [ ! -z ${BRANCH} ]; then
    git clone --single-branch -b $BRANCH $GIT_URL $PACKAGE
  else
    git clone $GIT_URL $PACKAGE
  fi
  if [ "$?" -ne 0 ]; then
    echo "Failed to clone $GIT_URL."
    exit 1
  fi
}


install_dev_repo() {
  cd $1
  PACKAGE=$2
  GIT_URL=$3
  BRANCH=$4
  if [ ! -z ${BRANCH} ]; then
    clone_dev_repo $1 $PACKAGE $GIT_URL $BRANCH
  else
    clone_dev_repo $1 $PACKAGE $GIT_URL
  fi
  cd $OPS/$PACKAGE
  pip install -e .
  if [ "$?" -ne 0 ]; then
    echo "Failed to run 'pip install -e .' for $PACKAGE."
    exit 1
  fi
}


move_and_link_repo() {
  cd $1
  PACKAGE=$2
  NEW_DIR=$3
  PACKAGE_DIR=${PACKAGE}-*
  mv $PACKAGE_DIR $NEW_DIR/
  cd $NEW_DIR
  ln -sf $PACKAGE_DIR $PACKAGE
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
    -d)
      DEV=1
      shift 1
      ;;
    --dev)
      DEV=1
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
    -k)
      GIT_OAUTH_TOKEN="$2"
      if [[ $GIT_OAUTH_TOKEN == "" ]]; then break; fi
      shift 2
      ;;
    --token=*)
      GIT_OAUTH_TOKEN="${1#*=}"
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


# check if both -d and -r were specified
if [ ! -z ${DEV+x} ] && [ ! -z ${RELEASE+x} ]; then
  echoerr "Error: Cannot specify -r/--release and -d/--dev options together."
  usage
fi


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
# install from git because master has support for python3
if [ ! -e "$INSTALL_DIR/bin/supervisord" ]; then
  #pip install --ignore-installed supervisor
  pip install --ignore-installed git+https://github.com/Supervisor/supervisor
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
if [[ "$GIT_OAUTH_TOKEN" == "" ]]; then
  GIT_URL="https://github.com"
  API_URL="https://api.github.com"
else
  GIT_URL="https://${GIT_OAUTH_TOKEN}@github.com"
  API_URL="https://${GIT_OAUTH_TOKEN}@api.github.com"
fi


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
if [ -z ${DEV+x} ] && [ -z ${RELEASE+x} ]; then
  echo "No release specified or development mode not set."
  echo "Use -d | --dev to install development mode or use -r RELEASE | --release=RELEASE"
  echo "to install a specific release. Listing available releases:"
  for tag in "${!rels[@]}"; do
    echo "$tag"
  done | sort
  exit 0
fi


# create ops directory
OPS="$INSTALL_DIR/ops"
if [ ! -d "$OPS" ]; then
  mkdir $OPS
fi
cd $OPS
  
  
# install dev environment
if [[ "$DEV" == 1 ]]; then
  # clone prov_es package
  install_dev_repo $OPS prov_es https://github.com/hysds/prov_es.git python3
  
  
  # clone osaka package
  pip install -U python-dateutil
  install_dev_repo $OPS osaka https://github.com/hysds/osaka.git python3
  
  
  # clone hysds_commons package
  install_dev_repo $OPS hysds_commons https://github.com/hysds/hysds_commons.git python3
  
  
  # clone hysds package
  cd $OPS
  PACKAGE=hysds
  clone_dev_repo $OPS $PACKAGE https://github.com/hysds/hysds.git python3
  cd $OPS/$PACKAGE/third_party/celery-v4.2.1
  pip install -e .
  cd $OPS/$PACKAGE
  pip install -e .
  if [ "$?" -ne 0 ]; then
    echo "Failed to run 'pip install -e .' for $PACKAGE."
    exit 1
  fi
  
  
  # clone sciflo package
  install_dev_repo $OPS sciflo https://github.com/hysds/sciflo.git python3
  
  
  # clone mozart package
  install_dev_repo $OPS mozart https://github.com/hysds/mozart.git python3
  
  
  # clone figaro package
  install_dev_repo $OPS figaro https://github.com/hysds/figaro.git python3
  
  
  # clone sdscli package
  pip install "cryptography==2.4.2"
  install_dev_repo $OPS sdscli https://github.com/sdskit/sdscli.git python3
  
  
  # clone grq2 package
  clone_dev_repo $OPS grq2 https://github.com/hysds/grq2.git python3
  
  
  # clone tosca package
  clone_dev_repo $OPS tosca https://github.com/hysds/tosca.git python3
  
  
  # clone spyddder-man package
  clone_dev_repo $OPS spyddder-man https://github.com/hysds/spyddder-man.git python3
  
  
  # clone lightweight-jobs package
  clone_dev_repo $OPS lightweight-jobs https://github.com/hysds/lightweight-jobs.git python3
  
  
  # clone container-builder package
  clone_dev_repo $OPS container-builder https://github.com/hysds/container-builder.git python3
  
  
  # clone s3-bucket-listing package
  clone_dev_repo $OPS s3-bucket-listing https://github.com/hysds/s3-bucket-listing.git
  
  
  # clone hysds-dockerfiles package
  clone_dev_repo $OPS hysds-dockerfiles https://github.com/hysds/hysds-dockerfiles.git python3
  
  
  # clone hysds-cloud-functions package
  clone_dev_repo $OPS hysds-cloud-functions https://github.com/hysds/hysds-cloud-functions.git
else
  # print release if not specified
  if [[ "$RELEASE" == "" ]]; then
    echo "No release specified. Use -r RELEASE | --release=RELEASE to install a specific release."
    echo "Listing available releases:"
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
  
  
  # download all assets for a release and untar
  declare -A assets
  for i in `${BASE_PATH}/query_releases.py $REL_API_URL -r $RELEASE`; do
    as_name=`echo $i | awk 'BEGIN{FS="|"}{print $1}'`
    as_url=`echo $i | awk 'BEGIN{FS="|"}{print $2}'`
    assets[$as_name]+=$as_url
    if [[ "$GIT_OAUTH_TOKEN" == "" ]]; then
        #echo wget --max-redirect=10 --header="Accept: application/octet-stream" \
        #     -O $as_name $as_url
        ${BASE_PATH}/download_asset.py $as_url $as_name
    else
        #echo wget --max-redirect=10 --header="Accept: application/octet-stream" \
        #     --header="Authorization: token $GIT_OAUTH_TOKEN" \
        #     -O $as_name $as_url
        ${BASE_PATH}/download_asset.py $as_url $as_name --token $GIT_OAUTH_TOKEN
    fi
    if [ "$?" -ne 0 ]; then
      echo "Failed to download asset $as_url."
      exit 1
    fi
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
  PACKAGE_DIR=${PACKAGE}-!(dockerfiles*|cloud-functions*|ops-bot*)
  ln -sf $PACKAGE_DIR $PACKAGE
  cd $OPS/$PACKAGE/third_party/celery-v4.2.1
  pip install -e .
  cd $OPS/$PACKAGE
  pip install -e .
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
  
  
  # export latest sdscli package
  pip install "cryptography==2.4.2"
  install_repo $OPS sdscli
  
  
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
  
  
  # export latest hysds-cloud-functions package
  link_repo $OPS hysds-cloud-functions
fi

# download hysds core packages and verdi image
${BASE_PATH}/download_latest.py $API_URL hysds lightweight-jobs -o ${INSTALL_DIR}/pkgs -s sdspkg.tar
${BASE_PATH}/download_latest.py $API_URL hysds hysds-dockerfiles -o ${INSTALL_DIR}/pkgs -s tar.gz
