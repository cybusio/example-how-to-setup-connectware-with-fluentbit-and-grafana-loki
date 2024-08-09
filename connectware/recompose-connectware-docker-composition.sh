#!/usr/bin/env bash
#
# Converts the standard Connectware composition to a variant
# using a centralized anchor for an logging object for which
# aliases are used as merge keys for every service definition.
#
# Prerequisites:
# - the 'yq' yaml processor (see https://mikefarah.gitbook.io/yq/)
#

# Make sure the script runs in the directory in which it is placed
cd $(dirname $([[ $0 = /* ]] && echo "$0" || echo "$PWD/${0#./}"))

printf "👷Recompose Connectware docker compositions for central logging configuration.\n\n"

function usage {
    printf "Usage:\n"
    printf "$0 --docker-composition|-dc <docker_compose_file> [--logging-driver|-log <logging-driver-name (json-file|fluentd)]>\n"
    exit 1
}

function argparse {
  printf "Given parameters: $*\n\n"

  if [ $# -eq 0 ]; then
      usage
  fi

  while [ $# -gt 0 ]; do
    case "$1" in
      --docker-composition|-dc)
        # the file name of the connectware docker composition
        export DOCKER_COMPOSE_FILE="${2}"
        shift
        ;;
      --logging-driver|-log)
        # the name of the logging driver (json, fluentd)
        export LOGGING_DRIVER_NAME="${2}"
        shift
        ;;
      *)
        printf "ERROR: Parameters invalid.\n"
        usage
    esac
    shift
  done
}

#
# init
export DOCKER_COMPOSE_FILE=docker-compose-connectware.yml
export LOGGING_DRIVER_NAME=json-file

argparse $*

if [ ! -f "${DOCKER_COMPOSE_FILE}" ]; then
  printf "❌ docker compose file '${DOCKER_COMPOSE_FILE}' does not exist.\n"
  usage
fi

#
# the logging driver name is used to identify a file containing a json object for the x-logging extension field
export LOGGING_DRIVER_CONFIGURATION_FILE=logging_anchor_${LOGGING_DRIVER_NAME}.yml
export TARGET_COMPOSITION_FILE=`echo ${DOCKER_COMPOSE_FILE} | sed "s/.yml//"`_${LOGGING_DRIVER_NAME}-logging.yml

if [ ! -f "${LOGGING_DRIVER_CONFIGURATION_FILE}" ]; then
  printf "❌ logging_anchor file missing for driver '${LOGGING_DRIVER_NAME}'.\n"
  usage
fi

#
# recomposes the docker composition for:
# - using anchors for a central logging driver configuration for all services
# - using a logging driver given as logging_anchor file (containing the extension field object)
#
function recompose_connectware {
  CONNECTWARE_DOCKER_COMPOSE_FILE=${1}
  TMP_COMPOSE_FILE="tmp__${DOCKER_COMPOSE_FILE}"

  # delete the version and the nested logging entries in the services array
  yq 'del(. | select(has("version"))."version" )' ${CONNECTWARE_DOCKER_COMPOSE_FILE} > ${TMP_COMPOSE_FILE}
  yq 'del(.services[] | select(has("logging"))."logging" )' ${TMP_COMPOSE_FILE} > ${TMP_COMPOSE_FILE}_work

  # rewrite the docker composition to move version and extension field to the top
  touch ${TMP_COMPOSE_FILE}

  # set the yaml version to the docker compose spec supporting extension fields (3.4 or higher)
  yq '. + {"version":"3.8"}' ${TMP_COMPOSE_FILE} > ${TMP_COMPOSE_FILE}

  # merge the extension field "x-logging" containing the anchor object for a given logging configuration
  cat ${LOGGING_DRIVER_CONFIGURATION_FILE} >> ${TMP_COMPOSE_FILE}

  # replace exiting logging objects per service definition with a merge key << *logging
  yq '.services.[].<< alias = "logging"' ${TMP_COMPOSE_FILE}_work >> ${TMP_COMPOSE_FILE}

  # build final docker composition
  cp -f ${TMP_COMPOSE_FILE} ${TARGET_COMPOSITION_FILE}

}

#
# removes temporary files
#
function cleanup {
  rm -f tmp__*
}

recompose_connectware ${DOCKER_COMPOSE_FILE}
cleanup

if [ ! -f "${TARGET_COMPOSITION_FILE}" ]; then
  printf "❌ recompose failed. target file '${TARGET_COMPOSITION_FILE}' does not exist.\n"
else
  printf "✅ recompose finished. See target file '${TARGET_COMPOSITION_FILE}'.\n"
fi
