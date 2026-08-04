#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Stopping Microservices Infrastructure${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

stop_stack() {
    local dir=$1
    local name=$2
    local action=${3:-down}
    
    echo -e "${YELLOW}Stopping $name...${NC}"
    cd "$dir"
    if [ "$action" == "down" ]; then
        docker compose --env-file ../.env down 
    else
        docker compose --env-file ../.env stop 
    fi
    cd - > /dev/null
    echo -e "${GREEN}✓ $name stopped${NC}"
}

REMOVE_VOLUMES=false
STOP_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--volumes)
            REMOVE_VOLUMES=true
            shift
            ;;
        -s|--stop-only)
            STOP_ONLY=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -v, --volumes     Remove volumes (WARNING: deletes all data)"
            echo "  -s, --stop-only   Stop containers without removing them"
            echo "  -h, --help        Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

if [ "$REMOVE_VOLUMES" = true ]; then
    echo -e "${RED}WARNING: This will remove all volumes and delete all data!${NC}"
    read -p "Are you sure? (type 'yes' to confirm): " -r
    if [[ ! $REPLY == "yes" ]]; then
        echo "Aborted."
        exit 0
    fi
fi

ACTION="down"
if [ "$STOP_ONLY" = true ]; then
    ACTION="stop"
fi

# Stop in reverse dependency order
stop_stack "05-ops" "Operations Layer" "$ACTION"
stop_stack "04-gateway" "Gateway Layer" "$ACTION"
stop_stack "03-observability" "Observability Layer" "$ACTION"
stop_stack "02-messaging" "Messaging Layer" "$ACTION"
stop_stack "01-data" "Data Layer" "$ACTION"

if [ "$REMOVE_VOLUMES" = true ]; then
    echo ""
    echo -e "${RED}Removing all volumes...${NC}"
    docker volume rm $(docker volume ls -q | grep -E "01-data|02-messaging|03-observability|04-gateway|05-ops") 2>/dev/null || true
    echo -e "${GREEN}✓ Volumes removed${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}All Services Stopped Successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

REMAINING=$(docker ps -a --format "{{.Names}}" | grep -E "postgres|mongo|redis|elastic|minio|kafka|prometheus|loki|tempo|grafana|otel|kong|keycloak|nginx|jenkins|portainer|trivy" | wc -l)

if [ "$REMAINING" -gt 0 ]; then
    echo -e "${YELLOW}Remaining containers:${NC}"
    docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep -E "postgres|mongo|redis|elastic|minio|kafka|prometheus|loki|tempo|grafana|otel|kong|keycloak|nginx|jenkins|portainer|trivy"
else
    echo -e "${GREEN}No infrastructure containers remaining.${NC}"
fi

if [ "$STOP_ONLY" = false ]; then
    echo ""
    echo -e "${YELLOW}To remove the network, run: docker network rm global-infra${NC}"
fi