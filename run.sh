#!/usr/bin/env bash

set -e

cd $(dirname "${0}")

## this is the default mode
## but it can be overridden via the "--mode=" CLI argument
## allowed values:
## * grafana-https
## * nginx-https
## * nginx-external
MODE="grafana-http"

CLI_MODE=$(echo "$@" | grep -oP 'mode=([a-zA-Z-]+)' | cut -d '=' -f 2)

if [[ -n "${CLI_MODE}" ]]; then
  MODE="${CLI_MODE}"
fi

OVERRIDE_YML="docker-compose.override.yml"

docker-compose stop

if [ -f "${OVERRIDE_YML}" ]; then
  rm -f ${OVERRIDE_YML}
fi

if [ -f ".env" ]; then
  while read line
  do
    IFS="=" read var_name var_value <<< "${line}"
    VAR_VALUE_TRIMMED=$(echo -e "${var_value}" | tr -d '[:space:]')
    VAR_NAME_TRIMMED=$(echo -e "${var_name}" | tr -d '[:space:]')
    if [[ ! -z "${VAR_VALUE_TRIMMED}" ]] && [[ "#" != "${VAR_NAME_TRIMMED:0:1}" ]]; then
      export ${VAR_NAME_TRIMMED}="${VAR_VALUE_TRIMMED}"
    fi
  done < .env
fi

GRAFANA_PORT="${GRAFANA_PORT:-3000}"
LOKI_PORT="${LOKI_PORT:-3100}"
NGINX_EXTERNAL_FOLDER="${NGINX_EXTERNAL_FOLDER:-/etc/nginx/conf.d}"

check_for_certificates() {
  if [ ! -f "ssl/live/${SSL_DOMAIN_NAME}/fullchain.pem" ]; then
    echo "SSL certificates not found for ${SSL_DOMAIN_NAME}. Run generate-ssl-certs.sh first."
    exit 1
  fi
}

generate_nginx_vhost_config() {
  cp nginx/template.conf nginx/grafana.conf
  sed -i \
    -e "s#SSL_DOMAIN_NAME#${SSL_DOMAIN_NAME}#g" \
    -e "s#LOKI_PORT#${LOKI_PORT}#g" \
    -e "s#GRAFANA_PORT#${GRAFANA_PORT}#g" \
    nginx/grafana.conf
}

case "${MODE}" in
  "grafana-http")
    echo "Running Loki with Grafana in HTTP mode"
    ;;

  "grafana-https")
    echo "Running Loki with Grafana in HTTPS mode"
    check_for_certificates
    cp docker-compose.grafana-https.yml docker-compose.override.yml
    ;;

  "nginx-https")
    echo "Running Loki with Grafana and Nginx in HTTPS mode"

    check_for_certificates

    generate_nginx_vhost_config

    sed -i \
        -e "s#localhost:${LOKI_PORT}#loki:${LOKI_PORT}#g" \
        -e "s#localhost:${GRAFANA_PORT}#grafana:${GRAFANA_PORT}#g" \
        nginx/grafana.conf

    cp docker-compose.nginx-https.yml docker-compose.override.yml
    ;;

  "nginx-external")
    echo "Running Loki with Grafana, Nginx is running standalone"

    check_for_certificates

    generate_nginx_vhost_config

    mkdir -p /etc/ssl/live/${SSL_DOMAIN_NAME}
    cp -rf ssl/live/${SSL_DOMAIN_NAME}/* /etc/ssl/live/${SSL_DOMAIN_NAME}/
    cp nginx/grafana.conf ${NGINX_EXTERNAL_FOLDER}/

    nginx -s reload
    ;;

  *)
    echo "Unknown mode: ${MODE}"
    exit 1
    ;;
esac

docker-compose up --detach --remove-orphans
