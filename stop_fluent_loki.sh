#!/usr/bin/env bash
#
# Starts the docker compositions for Fluent-Bit, Loki and Grafana
#
docker compose -f ./docker-compose-fluentbit.yml down -v
docker compose -f ./docker-compose-grafana-loki.yml down -v
