#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Microservices Infrastructure Status    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

check_service() {
    local service=$1
    local port=$2
    local path=${3:-"/"}
    
    if docker ps --format '{{.Names}}' | grep -q "^${service}$"; then
        local status=$(docker inspect --format='{{.State.Status}}' $service 2>/dev/null)
        local health=$(docker inspect --format='{{.State.Health.Status}}' $service 2>/dev/null)
        
        if [ "$status" == "running" ]; then
            if [ "$health" == "healthy" ] || [ "$health" == "<no value>" ]; then
                echo -e "${GREEN}✓${NC} $service - Running"
                return 0
            else
                echo -e "${YELLOW}⚠${NC} $service - Running (Health: $health)"
                return 1
            fi
        else
            echo -e "${RED}✗${NC} $service - Status: $status"
            return 1
        fi
    else
        echo -e "${RED}✗${NC} $service - Not found"
        return 1
    fi
}

check_port() {
    local port=$1
    local service=$2
    if nc -z localhost $port 2>/dev/null; then
        echo -e "  ${GREEN}→${NC} Port $port is accessible"
        return 0
    else
        echo -e "  ${RED}→${NC} Port $port not accessible ($service)"
        return 1
    fi
}

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Network Status${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if docker network inspect global-infra > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} global-infra network exists"
    CONTAINER_COUNT=$(docker network inspect global-infra --format='{{len .Containers}}')
    echo -e "  ${GREEN}→${NC} Connected containers: $CONTAINER_COUNT"
else
    echo -e "${RED}✗${NC} global-infra network not found"
fi
echo ""

# Data Layer
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}01 - Data Layer${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
check_service "postgres" 5432
check_port 5432 "PostgreSQL"
check_service "mongo" 27017
check_port 27017 "MongoDB"
check_service "redis" 6379
check_port 6379 "Redis"
check_service "elasticsearch" 9200
check_port 9200 "Elasticsearch"
check_service "minio" 9000
check_port 9000 "MinIO API"
check_port 9001 "MinIO Console"
echo ""

# Messaging Layer
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}02 - Messaging Layer${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
check_service "kafka" 9092
check_port 9092 "Kafka Broker"
check_port 29092 "Kafka External"
check_port 9093 "Kafka Controller"
check_service "kafka-ui" 8080
check_port 8080 "Kafka UI"
echo ""

# Observability Layer
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}03 - Observability Layer${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
check_service "prometheus" 9090
check_port 9090 "Prometheus"
check_service "loki" 3100
check_port 3100 "Loki"
check_service "tempo" 3200
check_port 3200 "Tempo"
check_service "otel-collector" 4317
check_port 4317 "OTel gRPC"
check_port 4318 "OTel HTTP"
check_service "grafana" 3000
check_port 3000 "Grafana"
echo ""

# Gateway Layer
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}04 - Gateway Layer${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
check_service "kong" 8000
check_port 8000 "Kong Proxy"
check_port 8001 "Kong Admin"
check_service "keycloak" 8080
check_port 8080 "Keycloak"
check_service "nginx" 80
check_port 80 "Nginx HTTP"
check_port 443 "Nginx HTTPS"
echo ""

# Operations Layer
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}05 - Operations Layer${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
check_service "jenkins" 8080
check_port 8080 "Jenkins"
check_service "portainer" 9000
check_port 9000 "Portainer"
check_service "trivy" 8082
check_port 8082 "Trivy"
echo ""

# Resource Usage
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Resource Usage${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | head -20
echo ""

# Summary
RUNNING=$(docker ps --filter "network=global-infra" --format '{{.Names}}' | wc -l)
TOTAL=$(docker ps -a --filter "network=global-infra" --format '{{.Names}}' | wc -l)
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Total Containers: ${GREEN}$RUNNING${NC} running / ${YELLOW}$TOTAL${NC} total"
echo ""