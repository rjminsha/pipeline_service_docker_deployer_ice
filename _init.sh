#!/bin/bash

#********************************************************************************
# Copyright 2014 IBM
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#********************************************************************************

#############
# Colors    #
#############
export green='\e[0;32m'
export red='\e[0;31m'
export label_color='\e[0;33m'
export no_color='\e[0m' # No Color

##################################################
# Simple function to only run command if DEBUG=1 # 
### ###############################################
debugme() {
  [[ $DEBUG = 1 ]] && "$@" || :
}
export -f debugme 

debugme echo "Current working directory and contents: "
debugme pwd 
debugme ls 
debugme echo

set +e

########################
# API Server           #
########################
if [ -z "$API_URL" ]; then
    export API_URL="https://api-ice.ng.bluemix.net/v1.0"
fi

#######################################
# Authorization and Authentication    #
#######################################
if [ -z $API_KEY ]; then
    if [[ "$DEBUG" == 1 ]] || [[ "$BUILD_USER" == "minshallrobbie" ]] || [[ "$CF_APP" == "ice-pipeline-demo" ]] || [[ "$CF_ORG" == "rjminsha@us.ibm.com" ]] || [[ "$GIT_URL" == "https://hub.jazz.net/git/rjminsha/ice-pipeline-demo" ]] || [[ "$GIT_URL" == "https://hub.jazz.net/git/rjminsha/container-pipeline-demo" ]]; then
        echo -e "${label_color}Using demo API key, please update set API_KEY in the environment${no_color}"
        export API_KEY="07889a87b6429714618fe23153c20e00cf02724573dedc9e"
    else 
        echo -e "${red}API_KEY must be set in the environement.  Add this in setenv.sh in the root of your project. ${no_color}"
        exit 1
    fi 
fi

######################
# Install ICE CLI    #
######################
debugme echo "##################"
debugme echo "installing ICE"
debugme echo "##################"
ice help >> init.log 2>&1  
RESULT=$?
if [ $RESULT -ne 0 ]; then
    pushd . 
    cd $EXT_DIR
    sudo apt-get -y install python2.7 >> init.log 2>&1 
    debugme more pythoninstall.log 
    python get-pip.py --user >> init.log 
    export PATH=$PATH:~/.local/bin
    pip install --user icecli-2.0.zip >> init.log 2>&1 
    ice help >> init.log 
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
        echo -e "${red}Failed to install IBM Container Service CLI ${no_color}"
        exit $RESULT
    fi 
    popd 
    echo -e "${label_color}Successfully installed IBM Container Service CLI ${no_color}"
fi 

ice login --key ${API_KEY} >> init.log 2>&1 
RESULT=$?
if [ $RESULT -eq 1 ]; then
    echo -e "${red}Failed to login to IBM Container Service${no_color}"
    exit $RESULT
fi 

###############################
# Configure extension PATH    #
###############################
if [ -n $EXT_DIR ]; then 
    export PATH=$EXT_DIR:$PATH
fi 

##############################
# Identify the Image to use  #
##############################
# If the IMAGE_NAME is set in the environment then use that.  
# Else assume the input is coming from the build.properties created and archived by the Docker builder job
if [ -z $IMAGE_NAME ]; then
    if [ -f "build.properties" ]; then
        . build.properties 
        export IMAGE_NAME
        more build.properties >> init.log
        echo "echo IMAGE_NAME: $IMAGE_NAME" >> init.log 
    else 
        echo -e "${red}IMAGE_NAME was not set in the environment, and no build.properties was included in the input to the job."       
    fi  
    if [ -z $IMAGE_NAME ]; then
        echo "${red}IMAGE_NAME not set.  Set the IMAGE_NAME in the environment or provide a Docker build job as input to this deploy job ${no_label}"
        exit 1
    fi 
else 
    echo -e "${label_color}Image being overridden by the environment.  Using ${IMAGE_NAME} ${no_color}"
fi 
########################
# Current Limitations  #
########################
if [ -z $IP_LIMIT ]; then 
    export IP_LIMIT=2
fi 
if [ -z $CONTAINER_LIMIT ]; then 
    export CONTAINER_LIMIT=8
fi 
sudo apt-get install bc >> init.log 2>&1 
debugme more init.log 

