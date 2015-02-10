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

export LOG_DIR=${EXT_DIR}

##################################################
# Simple function to only run command if DEBUG=1 # 
### ###############################################
debugme() {
  [[ $DEBUG = 1 ]] && "$@" || :
}
export -f debugme 

set +e
set +x 

###############################
# Configure extension PATH    #
###############################
if [ -n $EXT_DIR ]; then 
    export PATH=$EXT_DIR:$PATH
fi 

#################################
# Set Bluemix Host Information  #
#################################
if [ -n "$BLUEMIX_TARGET" ]; then
    if [ "$BLUEMIX_TARGET" == "staging" ]; then 
        export CCS_API_HOST="api-ice.stage1.ng.bluemix.net" 
        export CCS_REGISTRY_HOST="registry-ice.stage1.ng.bluemix.net"
        export BLUEMIX_API_HOST="api.stage1.ng.bluemix.net"
    else 
        echo -e "Targetting production bluemix"
        echo -e "${label_color}TBD: read targetted environment from cf config.json${no_color}"
        export CCS_API_HOST="api-ice.ng.bluemix.net" 
        export CCS_REGISTRY_HOST="registry-ice.ng.bluemix.net"
        export BLUEMIX_API_HOST="api.ng.bluemix.net"
    fi 
fi 

###################################
# Get Bluemix Target Information  #
###################################

# If API_KEY is not provided get the org and space information 
if [ -z "$API_KEY" ]; then 
    pushd . 
    cd ${EXT_DIR}
    $(node cf_parser.js ~/.cf/config.json)
    popd 
    debugme echo "got org $CF_BLUEMIX_ORG from config.json" 
    debugme echo "got space $CF_BLUEMIX_SPACE from config.json" 

    if [ -z "$BLUEMIX_ORG" ]; then 
        if [ -n $CF_BLUEMIX_ORG ]; then 
            export BLUEMIX_ORG=$CF_BLUEMIX_ORG
        elif [[ -z "$BLUEMIX_USER" ]]; then
            export BLUEMIX_ORG=$BLUEMIX_USER
        else 
            echo -e "${red}Please set $BLUEMIX_USER and $BLUEMIX_ORG on the environment${no_color}"
            exit 1
        fi 
        echo -e "${label_color} Using ${BLUEMIX_ORG} for Bluemix organization, please set BLUEMIX_ORG if on the environment if you wish to change this. ${no_color} "
    fi 
    if [ -z "$BLUEMIX_SPACE" ]; then
        if [ -n "CF_BLUEMIX_SPACE" ]; then  
            export BLUEMIX_SPACE=$CF_BLUEMIX_SPACE
        else 
            export BLUEMIX_SPACE="dev"
        fi 
        echo -e "${no_color} Using ${BLUEMIX_SPACE} for Bluemix space, please set BLUEMIX_SPACE if on the environment if you wish to change this. ${no_color} "
    fi 
fi 

# Get the Bluemix user and password information 
if [ -z "$BLUEMIX_USER" ]; then 
    export BLUEMIX_USER="${CF_BLUEMIX_ORG}"
    if [ -z "$BLUEMIX_USER" ]; then 
        echo -e "${red} Please set BLUEMIX_USER on environment ${no_color} "
        exit 1
    else 
        echo -e "${label_color} Using ${CF_BLUEMIX_ORG} as default user, please set BLUEMIX_USER on environment ${no_color} "
    fi 
fi 
if [ -z "$BLUEMIX_PASSWORD" ]; then 
    echo -e "${red} Please set BLUEMIX_PASSWORD as an environment property environment ${no_color} "
    exit 1 
fi 

echo -e "${label_color}Targetting information.  Can be updated by setting environment variables${no_color}"
echo "BLUEMIX_USER: ${BLUEMIX_SPACE}"
echo "BLUEMIX_SPACE: ${BLUEMIX_SPACE}"
echo "BLUEMIX_ORG: ${BLUEMIX_ORG}"
echo "BLUEMIX_PASSWORD: xxxxx"
echo ""

######################
# Install ICE CLI    #
######################
debugme echo "##################"
debugme echo "installing ICE"
debugme echo "##################"
ice help >> ${LOG_DIR}/ice.log 2>&1 
RESULT=$?
if [ $RESULT -ne 0 ]; then
    pushd . 
    cd $EXT_DIR
    sudo apt-get -y install python2.7 >> ${LOG_DIR}/ice.log 2>&1
    python get-pip.py --user >> ${LOG_DIR}/ice.log 2>&1
    export PATH=$PATH:~/.local/bin
    pip install --user icecli-2.0.zip >> ${LOG_DIR}/ice.log 2>&1
    ice help >> ${LOG_DIR}/ice.log 2>&1
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
        echo -e "${red}Failed to install IBM Container Service CLI ${no_color}"
        debugme more ${LOG_DIR}/ice.log 
        debugme python --version
        exit $RESULT
    fi
    popd 
    debugme more ${LOG_DIR}/ice.log 
    echo -e "${label_color}Successfully installed IBM Container Service CLI ${no_color}"
fi 

#############################
# Install Cloud Foundry CLI #
#############################
debugme echo "#############################"
debugme echo "# Install Cloud Foundry CLI #"
debugme echo "#############################"
echo -e "Cloud Foundry CLI not installed"
pushd . 
cd $EXT_DIR 
gunzip cf-linux-amd64.tgz >> ${LOG_DIR}/cf.log 2>&1 
tar -xvf cf-linux-amd64.tar >> ${LOG_DIR}/cf.log 2>&1 
cf help >> ${LOG_DIR}/cf.log 2>&1 
RESULT=$?
if [ $RESULT -ne 0 ]; then
    echo -e "${red}Could not install the cloud foundry CLI ${no_color}"
    debugme more ${LOG_DIR}/cf.log
    exit 1
fi  
popd
debugme more ${LOG_DIR}/cf.log
echo "Installed Cloud Foundry CLI"

################################
# Login to Container Service   #
################################
################################
# Login to Container Service   #
################################
if [ -n "$API_KEY" ]; then 
    echo -e "${label_color}Logging on with API_KEY${no_color}"
    ice login --key ${API_KEY} >> ${LOG_DIR}/login.log 2>&1
    RESULT=$?
elif [[ -n "$BLUEMIX_TARGET" ]]; then
    # User wants to specify all information 
    echo -e "${label_color}Logging via environment properties${no_color}"
    debugme echo "login command: ice --verbose login --cf -H ${CCS_API_HOST} -R ${CCS_REGISTRY_HOST} --api ${BLUEMIX_API_HOST}  --user ${BLUEMIX_USER} --psswd ${BLUEMIX_PASSWORD} --org ${BLUEMIX_ORG} --space ${BLUEMIX_SPACE}"
    ice login --cf -H ${CCS_API_HOST} -R ${CCS_REGISTRY_HOST} --api ${BLUEMIX_API_HOST}  --user ${BLUEMIX_USER} --psswd ${BLUEMIX_PASSWORD} --org ${BLUEMIX_ORG} --space ${BLUEMIX_SPACE} >> ${LOG_DIR}/login.log 2>&1
    RESULT=$?
else 
    # User wants to login to production container service 
    if [ -f "~/.cf/config.json" ]; then 
        # we are already logged in.  Simply check via ice command 
        echo -e "${label_color}Logging into IBM Container Service using credentials passed from IBM DevOps Services ${no_color}"
        echo "checking login to api server" >> ${LOG_DIR}/login.log 2>&1
        ice ps >> ${LOG_DIR}/login.log 2>&1
        RESULT=$?
        if [ $RESULT -ne 0 ]; then
            echo "checking login to registry server" >> ${LOG_DIR}/login.log 2>&1
            ice images >> ${LOG_DIR}/login.log 2>&1
            RESULT=$? 
        fi 
    else 
        # we need to login directly 
        echo -e "${label_color}Logging into IBM Container Service${no_color}"
            # User wants to specify all information 
            echo -e "${label_color}Logging via environment properties${no_color}"
            debugme echo "login command: ice --verbose login --cf -H ${CCS_API_HOST} -R ${CCS_REGISTRY_HOST} --api ${BLUEMIX_API_HOST}  --user ${BLUEMIX_USER} --psswd ${BLUEMIX_PASSWORD} --org ${BLUEMIX_ORG} --space ${BLUEMIX_SPACE}"
            ice --verbose login --cf -H ${CCS_API_HOST} -R ${CCS_REGISTRY_HOST} --api ${BLUEMIX_API_HOST}  --user ${BLUEMIX_USER} --psswd ${BLUEMIX_PASSWORD} --org ${BLUEMIX_ORG} --space ${BLUEMIX_SPACE} >> ${LOG_DIR}/login.log 2>&1
            RESULT=$?
    fi 
fi 

debugme ice info 
debugme more ${LOG_DIR}/login.log

# check login result 
if [ $RESULT -eq 1 ]; then
    echo -e "${red}Failed to login to IBM Container Service${no_color}"
    exit $RESULT
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

