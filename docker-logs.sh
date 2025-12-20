#!/bin/bash

################################################################################
# GRC Microservices - Docker Logs Script
#
# This script shows logs from Docker containers
################################################################################

# Set docker compose command
if docker compose version &> /dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

# Parse arguments
SERVICE=""
FOLLOW="-f"
TAIL="--tail=100"

while [[ $# -gt 0 ]]; do
    case $1 in
        --service|-s)
            SERVICE="$2"
            shift 2
            ;;
        --no-follow)
            FOLLOW=""
            shift
            ;;
        --tail|-n)
            TAIL="--tail=$2"
            shift 2
            ;;
        --all)
            TAIL=""
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -s, --service NAME    Show logs for specific service"
            echo "  --no-follow           Don't follow log output"
            echo "  -n, --tail NUMBER     Number of lines to show (default: 100)"
            echo "  --all                 Show all logs"
            echo "  --help                Show this help message"
            echo ""
            echo "Services:"
            echo "  back, notification-service, user-service, regulator-service,"
            echo "  strategic-plan-service, kpis, frontend, mongodb, redis"
            echo ""
            echo "Examples:"
            echo "  $0                           # Show all logs"
            echo "  $0 -s back                   # Show back service logs"
            echo "  $0 -s back --no-follow       # Show back logs without following"
            echo "  $0 --tail 50                 # Show last 50 lines"
            exit 0
            ;;
        *)
            SERVICE="$1"
            shift
            ;;
    esac
done

if [ -n "$SERVICE" ]; then
    echo "Showing logs for: $SERVICE"
    $DOCKER_COMPOSE logs $FOLLOW $TAIL "$SERVICE"
else
    echo "Showing logs for all services"
    $DOCKER_COMPOSE logs $FOLLOW $TAIL
fi
