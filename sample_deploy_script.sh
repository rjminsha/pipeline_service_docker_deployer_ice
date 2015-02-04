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
usage () { 
    echo -e "${label_color}Usage:${no_color}"
    echo "Set the following as a parameter on the job, or as an environment variable on the stage"
    echo "DEPLOY_TYPE: "
    echo "              simple: simply deploy a container and set the inventory"
    echo "              simple_public: simply deploy the container and assign a floating IP address to the container"
    echo "              red_black: deploy new container, assign floating IP address, keep original container"
    echo ""
    
    echo "The following environement variables can be set on the stage:"
    echo "DEPLOY_TYPE"
    echo "API_KEY"
    echo "IMAGE_NAME"
    echo "CONTAINER_NAME"
    echo "API_URL"
}

dump_info () {
    echo -e "${label_color}Container Information: ${no_color}"
    echo "Running Containers: "
    ice ps 
    echo "Available floating IP addresses"
    ice ip list --all
    echo "All floating IP addresses"
    ice ip list --all
    echo -e "${label_color}Current limitations:${no_color}"
    echo "     # of containers: 8"
    echo "     # of floating IP addresses: 2"
}

update_inventory(){
    echo "${red}TBD: update inventory${no_color}"
}

# function to wait for a container to start 
# takes a container name as the only parameter
wait_for (){
    local WAITING_FOR=$1 
    if [ -z ${WAITING_FOR} ]; then 
        echo "${red}Expected container name to be passed into wait_for${no_color}"
        return 1
    fi 
    COUNTER=0
    STATE="unknown"
    while [[ ( $COUNTER -lt 60 ) && ("${STATE}" == "BUILD") ]]; do
        let COUNTER=COUNTER+1 
        STATE=$(ice inspect $WAITING_FOR | grep "Status" | awk '{print $2}' | sed 's/"//g') && echo "${WAITING_FOR} is ${STATE}"
        sleep 1
    done
    if [ "$STATE" != "Running" ]; then
        echo -e "${red}Failed to start instance ${WAITING_FOR}"
        return 1
    fi  
    return 0 
}

deploy_container() {
    local MY_CONTAINER_NAME=$1 
    if [ -z MY_CONTAINER_NAME ];then 
        echo "${red}No container name was provided${no_color}"
        return 1 
    fi 

    # check to see if that container name is already in use 
    ice inspect ${MY_CONTAINER_NAME} > /dev/null
    FOUND=$?
    if [ ${FOUND} -eq 0 ]; then 
        echo -e "{red}${MY_CONTAINER_NAME} already exists.  If you wish to replace it remove it or use the red_black deployer strategy${no_color}"
        dump_info 
        return 1
    fi  

    # run the container and check the results
    ice run --name "${MY_CONTAINER_NAME}" ${IMAGE_NAME}
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
        echo -e "${red}Failed to deploy ${MY_CONTAINER_NAME} using ${IMAGE_NAME}${no_color}"
        dump_info
        return 1
    fi 

    # wait for container to start 
    wait_for ${MY_CONTAINER_NAME} 
    return 0
}

deploy_simple () {
    local MY_CONTAINER_NAME="${CONTAINER_NAME}_${BUILD_NUMBER}"
    deploy_container ${MY_CONTAINER_NAME}
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
        exit 1
    fi
    update_inventory
}

deploy_public () {
    # Check to see if the container is running 
    # If the container is running check to see if it has a floating IP address 
    # Check to see if a floating IP address is set in the configuration 
    # If the floating IP address in the configuration is different from the current one, 
    #       or if the floating IP address is not available then report an error 
    # Deploy new container using IMAGE_NAME and CONTAINER_NAME 
    # Assign floating IP address
    echo -e "${red}simple_public docker deploy not currently supported${no_color}"
    exit 1
}

deploy_red_black () {
    echo -e "${red}red_black docker deploy not currently supported${no_color}"
    exit 1
}
    
##################
# Initialization #
##################
# Check to see what deployment type: 
#   simple: simply deploy a container and set the inventory 
#   simple_public: simply deploy the container and assign a floating IP address to the container 
#   red_black: deploy new container, assign floating IP address, keep original container 
echo "Deploying using ${DEPLOY_TYPE} strategy, for ${CONTAINER_NAME}, deploy number ${BUILD_NUMBER}"
if [ "${DEPLOY_TYPE}" == "simple" ]; then
    deploy_simple
elif [ "${DEPLOY_TYPE}" == "simple_public" ]; then 
    deploy_public
elif [ "${DEPLOY_TYPE}" == "red_black" ]; then 
    deploy_red_black
else 
    echo -e "${label_color}Defaulting to simple deploy${no_color}"
    usage
    deploy_simple
fi 

