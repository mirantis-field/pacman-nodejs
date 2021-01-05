#!/bin/bash

BIN_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

docker-compose --file ${BIN_DIR}/../../swarm/docker-compose.development.yml --project-name pacman-dev up --build $@
