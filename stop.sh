#!/bin/bash
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Check directory
if [ -z "$1" ]; then
    echo -e "${GREEN}Usage: $0 <directory> [service] [-v]${NC}"
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

# Optional: service name
SERVICE="$2"

# Check for -v flag
VERBOSE=0
for arg in "$@"; do
    if [ "$arg" = "-v" ]; then
        VERBOSE=1
    fi
done

# Build docker-compose command
CMD="docker compose -p $LAST_FOLDER -f $DIR/docker-compose.yml down"

if [ -n "$SERVICE" ]; then
    CMD="$CMD $SERVICE"
fi

if [ "$VERBOSE" -eq 1 ]; then
    CMD="$CMD -v"
fi

echo -e "${GREEN}Executing: $CMD${NC}"
$CMD
