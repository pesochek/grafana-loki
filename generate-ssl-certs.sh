#!/usr/bin/env bash

set -e

cd $(dirname "${0}")

DOCKER_ENV=""
SSL_CERT_DIR="$(dirname "$0")/ssl"

# If we are running on Windows in MINGW64,
# we need to convert the path to a Windows path
if [ "msys" = "${OSTYPE}" ]; then
	SSL_CERT_DIR=$(cd ${SSL_CERT_DIR} ; pwd -W)
fi

if [ -f ".env" ]; then
  while read line
  do
    IFS="=" read var_name var_value <<< "${line}"
    VAR_VALUE_TRIMMED=$(echo -e "${var_value}" | tr -d '[:space:]')
    VAR_NAME_TRIMMED=$(echo -e "${var_name}" | tr -d '[:space:]')
    if [[ ! -z "${VAR_VALUE_TRIMMED}" ]] && [[ "#" != "${VAR_NAME_TRIMMED:0:1}" ]]; then
      DOCKER_ENV="${DOCKER_ENV} -e ${VAR_NAME_TRIMMED}=${VAR_VALUE_TRIMMED}"
    fi
  done < .env
fi

docker run \
  --rm \
  -it \
  ${DOCKER_ENV} \
  -v "${SSL_CERT_DIR}:/etc/letsencrypt" \
  certbot/dns-route53 \
  certonly \
  --dns-route53 \
  -d "${SSL_DOMAIN_NAME}" \
  --agree-tos
