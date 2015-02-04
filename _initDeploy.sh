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


#################################
# Specific init for Deploy Jobs #
#################################
# Look in build.properties for the IMAGE_URL
if [ -z $IMAGE_NAME ]; then
    if [ -f "build.properties" ]; then
        . build.properties 
    else 
        echo "could not find build.properties"
    fi  
    if [ -z $IMAGE_NAME ]; then
        echo "${red}IMAGE_NAME not set.  Set the IMAGE_NAME in the environment or provide a Docker build job as input to this deploy job ${no_label}"
        exit 1
    fi 
else 
    echo "IMAGE_URL: ${IMAGE_NAME}"
fi 

