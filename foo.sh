if [ -z $CONTAINER_NAME ]; then 
    export CONTAINER_NAME=#CONTAINER_NAME#
    if [ $CONTAINER_NAME -eq "#CONTAINER_NAME#" ]; then 
        echo -e "${red}CONTAINER_NAME must be set either as a parameter on the job, or as an environment variable on the stage ${no_label}"
        exit 1
    fi 
else 
    echo -e "${label_key}Container name is set in the environment to ${CONTAINER_NAME}, overridding parameters"
fi 