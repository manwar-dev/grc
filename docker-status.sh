#!/bin/bash

################################################################################
# GRC Microservices - Docker Status Script
#
# This script shows the status of all Docker containers
################################################################################

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Set docker compose command
if docker compose version &> /dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

echo "=========================================="
echo "GRC Microservices - Container Status"
echo "=========================================="
echo ""

# Check if any containers are running
if [ -z "$($DOCKER_COMPOSE ps -q 2>/dev/null)" ]; then
    echo -e "${RED}No containers are running${NC}"
    echo ""
    echo "To start services, run: bash docker-up.sh"
    exit 0
fi

# Show container status
$DOCKER_COMPOSE ps

echo ""
echo "=========================================="
echo "Container Health"
echo "=========================================="
echo ""

# Check health of each container
for container in $(docker ps --format "{{.Names}}" | grep "^grc-"); do
    health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no healthcheck")
    status=$(docker inspect --format='{{.State.Status}}' "$container")

    if [ "$health" = "healthy" ] || [ "$health" = "no healthcheck" ] && [ "$status" = "running" ]; then
        echo -e "${GREEN}✓${NC} $container: $status"
    elif [ "$status" = "running" ]; then
        echo -e "${YELLOW}⚠${NC} $container: $status (health: $health)"
    else
        echo -e "${RED}✗${NC} $container: $status"
    fi
done

echo ""
echo "=========================================="
echo "Resource Usage"
echo "=========================================="
echo ""

docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" | grep "^grc-"

echo ""
echo "=========================================="
echo "Useful Commands"
echo "=========================================="
echo ""
echo "View logs:          bash docker-logs.sh"
echo "View service logs:  bash docker-logs.sh -s [service-name]"
echo "Restart service:    $DOCKER_COMPOSE restart [service-name]"
echo "Stop all:           bash docker-down.sh"
echo "Execute command:    $DOCKER_COMPOSE exec [service-name] [command]"
echo ""
