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
    echo "CONTAINER_LIMIT"
    echo "IP_LIMIT"

}

dump_info () {
    echo -e "${label_color}Container Information: ${no_color}"
    echo "Running Containers: "
    ice ps 
    echo "Available floating IP addresses"
    ice ip list --all
    echo "All floating IP addresses"
    ice ip list --all

    if [[ (-z $IP_LIMIT) || (-z $CONTAINER_LIMIT) ]]; then 
        echo "Expected Container Service Limits to be set on the environment"
        return 1
    fi 

    echo -e "${label_color}Current limitations:${no_color}"
    echo "     # of containers: ${CONTAINER_LIMIT}"
    echo "     # of floating IP addresses: ${IP_LIMIT}"

    WARNING_LEVEL="$(echo "$CONTAINER_LIMIT - 2" | bc)"
    CONTAINER_COUNT=$(ice ps -q | wc -l | sed 's/^ *//') 
    if [ ${CONTAINER_COUNT} -ge ${CONTAINER_LIMIT} ]; then 
        echo -e "${red}You have ${CONTAINER_COUNT} containers running, and may reached the default limit on the number of containers ${no_color}"
    elif [ $CONTAINER_COUNT -ge $WARNING_LEVEL ]; then
        echo -e "${label_color}There are ${CONTAINER_COUNT} containers running, which is approaching the limit of ${CONTAINER_LIMIT}${no_color}"
    fi 

    IP_COUNT_REQUESTED=$(ice ip list --all | grep "Number" | sed 's/.*: \([0-9]*\).*/\1/')
    IP_COUNT_AVAILABLE=$(ice ip list | grep "Number" | sed 's/.*: \([0-9]*\).*/\1/')
    echo "Number of IP Addresses currently requested: $IP_COUNT_REQUESTED"
    echo "Number of requested IP Addresses that are still available: $IP_COUNT_AVAILABLE"
    AVAILABLE="$(echo "$IP_LIMIT - $IP_COUNT_REQUESTED + $IP_COUNT_AVAILABLE" | bc)"

    if [ ${AVAILABLE} -eq 0 ]; then 
        echo -e "${red}You have reached the default limit for the number of available public IP addresses${no_color}"
    else
        echo -e "${label_color}You have ${AVAILABLE} public IP addresses remaining${no_color}"
    fi  
}

update_inventory(){
    echo -e "${red}TBD: update inventory${no_color}"
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
    while [[ ( $COUNTER -lt 60 ) && ("${STATE}" != "Running") ]]; do
        let COUNTER=COUNTER+1 
        STATE=$(ice inspect $WAITING_FOR | grep "Status" | awk '{print $2}' | sed 's/"//g') && echo "${WAITING_FOR} is ${STATE}"
        sleep 1
    done
    if [ "$STATE" != "Running" ]; then
        echo -e "${red}Failed to start instance ${no_color}"
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
        echo -e "${red}${MY_CONTAINER_NAME} already exists.  If you wish to replace it remove it or use the red_black deployer strategy${no_color}"
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
    RESULT=$?
    return ${RESULT}
}

deploy_simple () {
    local MY_CONTAINER_NAME="${CONTAINER_NAME}_${BUILD_NUMBER}"
    deploy_container ${MY_CONTAINER_NAME}
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
        exit $RESULT
    fi
    dump_info
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
    echo -e "${label_color}Example red_black container deploy ${no_color}"
    # deploy new version of the application 
    local MY_CONTAINER_NAME="${CONTAINER_NAME}_${BUILD_NUMBER}"
    deploy_container ${MY_CONTAINER_NAME}
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
        exit $RESULT
    fi

    COUNTER=${BUILD_NUMBER}
    let COUNTER-=1
    until [  $COUNTER -lt 1 ]; do
        ice inspect ${CONTAINER_NAME}_${COUNTER} > inspect.log 
        RESULT=$?
        if [ $RESULT -eq 0 ]; then
            echo "Found previous container ${CONTAINER_NAME}_${COUNTER}"
            # does it have a public IP address 
            FLOATING_IP=$(cat inspect.log | grep "PublicIpAddress" | awk '{print $2}')
            temp="${FLOATING_IP%\"}"
            FLOATING_IP="${temp#\"}"
            if [ -z "${FOUND}" ]; then 
                # this is the first previous deployment I have found
                if [ -z "${FLOATING_IP}" ]; then 
                    echo "${CONTAINER_NAME}_${COUNTER} did not have a floating IP so allocating one"
                else 
                    echo "${CONTAINER_NAME}_${COUNTER} had a floating ip ${FLOATING_IP}"
                    ice ip unbind ${FLOATING_IP} ${CONTAINER_NAME}_${COUNTER}
                    ice ip bind ${FLOATING_IP} ${CONTAINER_NAME}_${BUILD_NUMBER}
                    echo "keeping previous deployment: ${CONTAINER_NAME}_${COUNTER}"
                fi 
                FOUND="true"
            else 
                # remove
                echo "removing previous deployment: ${CONTAINER_NAME}_${COUNTER}" 
                echo "ice rm ${CONTAINER_NAME}_${COUNTER}"
            fi  
        fi 
        let COUNTER-=1
    done
    # check to see that I obtained a floating IP address
    ice inspect ${CONTAINER_NAME}_${BUILD_NUMBER} > inspect.log 
    FLOATING_IP=$(cat inspect.log | grep "PublicIpAddress" | awk '{print $2}')
    if [ "${FLOATING_IP}" = '""' ]; then 
        echo "Requesting IP"
        FLOATING_IP=$(ice ip request | awk '{print $4}')
        RESULT=$?
        if [ $RESULT -ne 0 ]; then
            echo -e "${red}Failed to allocate IP address ${no_color}" 
            exit 1 
        fi
        temp="${FLOATING_IP%\"}"
        FLOATING_IP="${temp#\"}"
        ice ip bind ${FLOATING_IP} ${CONTAINER_NAME}_${BUILD_NUMBER}
        RESULT=$?
        if [ $RESULT -ne 0 ]; then
            echo -e "${red}Failed to bind ${FLOATING_IP} to ${CONTAINER_NAME}_${BUILD_NUMBER} ${no_color}" 
            exit 1 
        fi 
    fi 
    echo -e "${label_color}Public IP address of ${CONTAINER_NAME}_${BUILD_NUMBER} is ${FLOATING_IP} ${no_color}"
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
    echo -e "${label_color}Defaulting to red_black deploy${no_color}"
    usage
    deploy_red_black
fi 

