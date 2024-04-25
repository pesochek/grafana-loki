#!/usr/bin/env bash

set -x

cp docker-compose.grafana-https.yml docker-compose.override.yml

docker-compose stop

docker-compose up --detach
