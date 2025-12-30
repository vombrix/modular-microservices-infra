#!/bin/bash
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

if [ -z "$1" ]; then
    echo -e "${GREEN}Usage: $0 <directory> [service]${NC}"
    exit 1
fi

DIR="${1%/}"
if [ ! -d "$DIR" ]; then
    echo -e "${RED}Error: '$DIR' is not a directory.${NC}"
    exit 1
fi

if [ ! -f "$DIR/docker-compose.yml" ]; then
    echo -e "${RED}Error: '$DIR' does not contain docker-compose.yml.${NC}"
    exit 1
fi

LAST_FOLDER="${DIR##*/}"

if [ -z "$2" ]; then
    echo -e "${GREEN}Restarting $LAST_FOLDER stack${NC}"
    docker compose -p $LAST_FOLDER --env-file .env -f $DIR/docker-compose.yml restart
else
    echo -e "${GREEN}Restarting $2 service from $LAST_FOLDER stack${NC}"
    docker compose -p $LAST_FOLDER --env-file .env -f $DIR/docker-compose.yml restart $2
fi
