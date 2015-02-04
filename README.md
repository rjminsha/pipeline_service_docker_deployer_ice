# IBM DevOps Services Pipeline Extension for Deployment to IBM Container Service

## Overview
--------
Provides extension point for IBM DevOps Services to deploy a docker container using the IBM Container Service.  

## Prereqs 
- Project owner has configured IBM DevOps Services Project to deploy to IBM Bluemix including setting up space and organization 
- Project owner has added Pipeline Service and Container Service in IBM Bluemix

## Input 
- Image has been built and is located in the registry 
- Project owners Bluemix token will be automatically provided by the pipeline to the extension point for deployment

## Output 
Running container of image <registryurl>/<application_name>:<version> named <application_name><stage>

## Feedback and help
The point of this project is to experiment, learn and get feedback.  We believe that a deployment pipeline for Docker containers maybe a valuable thing. However, we would like to hear from you and get your input. 

You can start a discussion and leave feedback right on this project! Go to track and plan (top Right) and create a work item.  

## References
- [IBM Bluemix](https://console.ng.bluemix.net/)
- [IBM Container Service](https://developer.ibm.com/bluemix/2014/12/04/ibm-containers-beta-docker/)
- [Introduction to containers and bluemix](https://www.youtube.com/watch?v=-fcMeHdjC2g)