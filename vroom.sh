#!/usr/bin/env bash


__update_file() {

    usage() {

        echo "Usage: __update_file [OPTIONS] ... SOURCE_FILE DESTINATION_FILE
              Check if DESTINATION_FILE exists or is older than SOURCE_FILE and
              if so, the SOURCE_FILE will be copied into DESTINATION_FILE.

              Exit status:
                0  if copy was done successfully,
                1  if erro has occurred because source file does not exist,
                2  if copy was done successfully with replacement,
                3  if copy did not happen because the two files were identical,"

    }

    SOURCE_FILE=$1
    DESTINATION_FILE=$2

    echo "Updating ${DESTINATION_FILE} with ${SOURCE_FILE}."

    if [ ! -f ${SOURCE_FILE} ]; then
        echo "Error: SOURCE_FILE:${SOURCE_FILE} does not exist."
        usage
        exit 1
    fi

    if [ ! -f ${DESTINATION_FILE} ]; then
        echo "${DESTINATION_FILE} does not exist. Just doing a normal copy ..."
        cp --force ${SOURCE_FILE} ${DESTINATION_FILE}
        echo "Done"
        return 0
    else
        echo "${DESTINATION_FILE} exists. Checking for replacement ..."
        if [ ${SOURCE_FILE} -nt ${DESTINATION_FILE} ]; then
            echo "${DESTINATION_FILE} is older than ${SOURCE_FILE}. Just doing a replacement."
            cp --update --force ${SOURCE_FILE} ${DESTINATION_FILE}
            echo "Done."
            return 2
        else
            echo "${DESTINATION_FILE} and ${SOURCE_FILE} are the same. No replacement occured."
            return 3
        fi
    fi

}


__update_directory() {

    usage() {

        echo "Usage: __update_directory [OPTIONS] ... DIRECTORY
              Check if directory exists and if not, it will be
              created alongside with its parents

              Exit status:
                0  if directory update was done successfully,
                1  if directory update did not proceed as it existed"

    }

    DIRECTORY=$1

    echo "Creating ${DIRECTORY}. Checking if it exists ..."

    if [ ! -d ${DIRECTORY} ]; then
        echo "${DIRECTORY} does not exist. Creating ${DIRECTORY} ... "
        mkdir -p ${DIRECTORY}
        echo "Done."
        return 0
    else
        echo "${DIRECTORY} exists. There is no need for creation."
        return 1
    fi

}


__get_vroom_container_id() {

    usage() {

        echo "Usage: __get_vroom_container_id
              Check if VROOM_CONTAINER_ID is defined in VROOM_CONFIG_FILE and if so it gets it.

              Exit status:
                0  if OK,
                1  if any error occured,"

    }

    echo "Getting VROOM container ID. Checking ${VROOM_CONFIG_FILE} for VROOM_CONFIG_FILE container ID ..."

    PATTERN_LINE=$(grep "VROOM_CONTAINER_ID" ${VROOM_CONFIG_FILE})

    if [ "${PATTERN_LINE}" == "" ]; then
        VROOM_CONTAINER_ID=""
        echo "Could not find VROOM container ID."
    else
        VROOM_CONTAINER_ID="${PATTERN_LINE:19}"
        echo "VROOM container ID found. It is ${VROOM_CONTAINER_ID}"
    fi

    return 0

}


__error_no_container_found() {

    usage() {

        echo "Usage: __error_no_container_found
              Raises error because docker id is not available in VROOM_CONFIG_FILE."

    }

    echo "Error: There is no VROOM container available to work with"
    echo "Please start VROOM container first by executing command:"
    echo "      vroom start"

}


start() {

    usage() {

        echo "Usage: vroom start
              Checks if vroom container has not started yet and if not, it starts 
              the container and stores it's id as an environment variable.

              Exit status:
                0  if OK,
                1  if any error occured"

    }

    echo "Starting VROOM container."

    shift

    __get_vroom_container_id
    if [ "${VROOM_CONTAINER_ID}" != "" ]; then
        echo "Checking if VROOM container with ID = ${VROOM_CONTAINER_ID:0:12} is up and running ..."
        IS_DOCKER_UP=$(docker ps | grep "${VROOM_DOCKER_NAME}")
        if [ "${IS_DOCKER_UP}" == "" ]; then
            echo "VROOM container is not running. Starting it up ..."
            docker start "${VROOM_CONTAINER_ID}"
            echo "Done."
        else
            echo "${VROOM_DOCKER_NAME} is already up and running with ID = ${VROOM_CONTAINER_ID:0:12}."
            echo "You may want to proceed further."
        fi
        exit 0
    else
        echo "Creating VROOM container on local host"
        VROOM_CONTAINER_ID=$(docker create -t --name vroom --net host -v "${VROOM_CONF_DIR}:/conf" -e VROOM_ROUTER=osrm ${VROOM_DOCKER_NAME}:${VROOM_VERSION})
        echo "Done."
        echo "Writting VROOM_CONTAINER_ID in ${VROOM_CONFIG_FILE} ..."
        echo "VROOM_CONTAINER_ID=${VROOM_CONTAINER_ID}" >> ${VROOM_CONFIG_FILE}
        echo "Done."
        echo "Starting VROOM container ..."
        docker start "${VROOM_CONTAINER_ID}"
        echo "Done."
        exit 0
    fi

}


stop() {

    usage() {

        echo "Usage: vroom stop
              Checks if ${VROOM_DOCKER_NAME} docker has started and if so, it stops 
              the docker.

              Exit status:
                0  if OK,
                1  if any error occured"

    }

    echo "Stopping VROOM container."

    shift

    __get_vroom_container_id
    if [ "${VROOM_CONTAINER_ID}" == "" ]; then
        __error_no_container_found
        exit 1
    fi
    
    echo "Stopping VROOM container ..."
    docker stop "${VROOM_CONTAINER_ID}"
    echo "Done."

    exit 0

}


if [ ! -v VROOM_HOME_DIR ] || [ "${VROOM_HOME_DIR}" == "" ]; then
    echo "Error: VROOM_HOME_DIR environment variable is not defined."
    echo "Please define this variable and try again"
    exit 1
else
    echo "Using ${VROOM_HOME_DIR} as VROOM home directory."
    VROOM_CONF_DIR="${VROOM_HOME_DIR}/conf"
    echo "Using ${VROOM_CONF_DIR} as VROOM conf directory."
    VROOM_CONFIG_FILE="${VROOM_HOME_DIR}/vroom.config"
    echo "Using ${VROOM_CONFIG_FILE} as VROOM config file."
    if [ ! -d "${VROOM_CONF_DIR}" ]; then
        __update_directory "${VROOM_CONF_DIR}"
        echo "Done."
    fi
    if [ ! -f "${VROOM_CONFIG_FILE}" ]; then
        echo "${VROOM_CONFIG_FILE} does not exist, creating one ..."
        touch "${VROOM_CONFIG_FILE}"
        echo "Done."
    fi
fi
VROOM_VERSION="v1.12.0"
VROOM_DOCKER_NAME="vroomvrp/vroom-docker"


if [ $# -gt "0" ]; then
    case "${1}" in
        "start")
            start $@
            ;;
        "stop")
            stop $@
            ;;
    esac
fi
