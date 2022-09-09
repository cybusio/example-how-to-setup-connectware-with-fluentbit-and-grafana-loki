#!/usr/bin/env bash
#
# Converts the standard Connectware composition to a variant
# using a centralized anchor for an logging object for which
# aliases are used as merge keys for every service definition.
#
# Prerequisites:
# - the 'yq' yaml processor (see https://mikefarah.gitbook.io/yq/)
#
CONNECTWARE_COMPOSE_FILE=${1:-docker-compose-connectware.yml}
TMP_COMPOSE_FILE="tmp__${CONNECTWARE_COMPOSE_FILE}"

# delete the version and the nested logging entries in the services array
yq 'del(. | select(has("version"))."version" )' ${CONNECTWARE_COMPOSE_FILE} > ${TMP_COMPOSE_FILE}
yq 'del(.services[] | select(has("logging"))."logging" )' ${TMP_COMPOSE_FILE} > ${TMP_COMPOSE_FILE}_work

# rewrite the docker composition to move version and extension field to the top
touch ${TMP_COMPOSE_FILE}_prepare

# set the yaml version to the docker compose spec supporting extension fields (3.4 or higher)
yq '. + {"version":"3.4"}' ${TMP_COMPOSE_FILE}_prepare > ${TMP_COMPOSE_FILE}_prepare

# merge the extension field "x-logging" containing the anchor object for fluentd logging
yq '. *= load("logging_anchor.yml")' ${TMP_COMPOSE_FILE}_prepare > ${TMP_COMPOSE_FILE}

# replace exiting logging objects per service definition with a merge key << *logging
yq '.services.[].<< alias = "logging"' ${TMP_COMPOSE_FILE}_work >> ${TMP_COMPOSE_FILE}

# build final docker composition
cp -f ${TMP_COMPOSE_FILE} ${CONNECTWARE_COMPOSE_FILE}.converted

# cleanup
rm -f tmp__*
