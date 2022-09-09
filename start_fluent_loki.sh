#!/usr/bin/env bash
#
# Starts the docker compositions for Fluent-Bit, Loki and Grafana
#
docker compose -f ./docker-compose-loki.yml up -d
docker compose -f ./docker-compose-fluentbit.yml up -d
