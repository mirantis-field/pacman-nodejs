#!/bin/bash

BIN_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

docker-compose --file ${BIN_DIR}/../../swarm/docker-compose.production.yml --project-name pacman-prod up --build $@
