#!/usr/bin/env bash
#
# Starts the docker compositions for Fluent-Bit, Loki and Grafana
#
docker compose -f ./docker-compose-loki.yml down
docker compose -f ./docker-compose-fluentbit.yml down
