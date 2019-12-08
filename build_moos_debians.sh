#!/bin/bash

# Get directory of script, regarless of where the script is run.
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

HAS_SUDO=false
PROMPT=$(sudo -vn 2>&1)
if [ $? -eq 0 ]; then
  # exit code of sudo-command is 0
  HAS_SUDO=true
elif echo ${PROMPT} | grep -q '^sudo:'; then
  sudo -v
  echo "Run script again now that privilages have been obtained"
else
  echo "no_sudo"
fi

#
# SETTINGS
#
MOOS_VERSION="19.8.1"
MOOS_PATH=${DIR}/moos-ivp
PREFIX_PATH=${MOOS_PATH}/prefix
PACKAGE_PATH=${DIR}/packages
MOOS_CORE_PATH=${MOOS_PATH}/MOOS/MOOSCore

#
# FUNCTIONS
#
build_library() {
  MOOS_ROOT=$1
  PATH_TO_SRC_WITH_CMAKE=$2
  PREFIX_OUTPUT_PATH=$3
  
  mkdir ${MOOS_ROOT}/build
  mkdir ${PREFIX_OUTPUT_PATH}
  
  cd ${MOOS_ROOT}/build
  cmake -DCMAKE_INSTALL_PREFIX:PATH=${PREFIX_OUTPUT_PATH} ${PATH_TO_SRC_WITH_CMAKE}
  make -j
  make install
}

build_package() {
  MOOS_ROOT=$1
  PREFIX_OUTPUT_PATH=$2
  DEFAULT_TRUE_DEV_FALSE=$3
  PACKAGE_NAME=$4
  PACKAGE_VERSION=$5
  PACKAGE_OUTPUT_PATH=$6
  
  if [ "${DEFAULT_TRUE_DEV_FALSE}" = true ]; then
    DEB_PACKAGE_NAME=${PACKAGE_NAME}-${PACKAGE_VERSION}
  else
    DEB_PACKAGE_NAME=${PACKAGE_NAME}-dev-${PACKAGE_VERSION}
  fi
  
  # Remove existing debs
  rm ${MOOS_ROOT}/*.deb
  
  mkdir ${MOOS_ROOT}/${DEB_PACKAGE_NAME}
  cd ${MOOS_ROOT}/${DEB_PACKAGE_NAME}
  
  export DEBEMAIL="jason@jasonklein.me"
  export DEBFULLNAME="Jason Klein"
  
  # Copy binaries and libraries
  if [ "${DEFAULT_TRUE_DEV_FALSE}" = true ]; then
    mkdir ${MOOS_ROOT}/${DEB_PACKAGE_NAME}/bin
    cp ${PREFIX_OUTPUT_PATH}/bin/* ${MOOS_ROOT}/${DEB_PACKAGE_NAME}/bin/.
    
    mkdir ${MOOS_ROOT}/${DEB_PACKAGE_NAME}/lib
    cp ${PREFIX_OUTPUT_PATH}/lib/* ${MOOS_ROOT}/${DEB_PACKAGE_NAME}/lib/.
  else
    mkdir ${MOOS_ROOT}/${DEB_PACKAGE_NAME}/include
    cp -r ${PREFIX_OUTPUT_PATH}/include/* ${MOOS_ROOT}/${DEB_PACKAGE_NAME}/include/.
  fi
  
  # Setup the .deb working area
  dh_make --indep --createorig -y
  
  # Remove example files
  rm ${MOOS_ROOT}/${DEB_PACKAGE_NAME}/debian/*.ex
  
  # Configure files to be installed
  touch ${MOOS_ROOT}/${DEB_PACKAGE_NAME}/debian/install
  
  if [ "${DEFAULT_TRUE_DEV_FALSE}" = true ]; then
    echo "bin/* usr/bin" >> ${MOOS_ROOT}/${DEB_PACKAGE_NAME}/debian/install
    echo "lib/* usr/lib" >> ${MOOS_ROOT}/${DEB_PACKAGE_NAME}/debian/install
    
    for entry in bin/*
    do
        echo "${entry}" >> ${MOOS_ROOT}/${DEB_PACKAGE_NAME}/debian/source/include-binaries
    done

    for entry in lib/*
    do
        echo "${entry}" >> ${MOOS_ROOT}/${DEB_PACKAGE_NAME}/debian/source/include-binaries
    done
    
    # Create the .deb
    debuild -us -uc
    
  else
    echo "include/* usr/include" >> ${MOOS_ROOT}/${DEB_PACKAGE_NAME}/debian/install
    
    # Create the .deb
    debuild -b -us -uc
  fi
  
  cp ${MOOS_ROOT}/*.deb ${PACKAGE_OUTPUT_PATH}/.
}

#
# MAIN
#
if [ "${HAS_SUDO}" = true ]; then
  # Install moos-ivp dependencies
  sudo apt-get --assume-yes install libfltk1.3-dev libtiff-dev dh-make devscripts subversion cmake binutils build-essential
  
  # Remove existing svn checkout
  rm -rf ${MOOS_PATH}
  
  # Checkout repo
  svn co https://oceanai.mit.edu/svn/moos-ivp-aro/releases/moos-ivp-${MOOS_VERSION} ${MOOS_PATH}

  mkdir ${PACKAGE_PATH}

  build_library ${MOOS_PATH} ${MOOS_CORE_PATH} ${PREFIX_PATH}
  
  build_package ${MOOS_PATH} ${PREFIX_PATH} false "moos-ivp" ${MOOS_VERSION} ${PACKAGE_PATH}
  
  cd ${MOOS_PATH}
  ${MOOS_PATH}/build.sh -c
  ${MOOS_PATH}/build.sh
  
  cp ${DIR}/moos-ivp/build/MOOS/*/bin/* ${DIR}/moos-ivp/bin/.
  cp ${DIR}/moos-ivp/build/MOOS/*/lib/* ${DIR}/moos-ivp/lib/.
  
  build_package ${MOOS_PATH} ${MOOS_PATH} true "moos-ivp" ${MOOS_VERSION} ${PACKAGE_PATH}
fi




