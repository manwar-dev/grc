#!/bin/bash

################################################################################
# GRC Microservices - Docker Start Script
#
# This script starts all Docker containers for the GRC platform
################################################################################

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "=========================================="
echo "GRC Microservices - Starting Services"
echo "=========================================="
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    log_error "Docker is not running. Please start Docker first."
    exit 1
fi

# Set docker compose command
if docker compose version &> /dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

# Check if .env exists
if [ ! -f .env ]; then
    log_warn ".env file not found. Creating from .env.docker..."
    cp .env.docker .env
    log_info "Please review .env file and update if needed."
    echo ""
fi

# Parse arguments
DETACHED="-d"
PROFILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --foreground|-f)
            DETACHED=""
            shift
            ;;
        --production|-p)
            PROFILE="--profile production"
            shift
            ;;
        --build|-b)
            BUILD="--build"
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -f, --foreground    Run in foreground (show logs)"
            echo "  -p, --production    Start with production profile (includes gateway)"
            echo "  -b, --build         Build images before starting"
            echo "  --help              Show this help message"
            echo ""
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Build if requested
if [ -n "$BUILD" ]; then
    log_info "Building images..."
    bash docker-build.sh
    echo ""
fi

# Start services
log_info "Starting GRC microservices..."
echo ""

$DOCKER_COMPOSE up $DETACHED $PROFILE $BUILD

if [ $? -eq 0 ]; then
    if [ -n "$DETACHED" ]; then
        echo ""
        log_info "Services started successfully!"
        echo ""

        # Wait a moment for services to initialize
        sleep 5

        # Show status
        log_info "Service Status:"
        $DOCKER_COMPOSE ps

        echo ""
        echo "=========================================="
        echo "Service URLs"
        echo "=========================================="
        echo ""
        echo "Frontend:              http://localhost"
        echo "Main Backend:          http://localhost:9090"
        echo "Notification Service:  http://localhost:6060"
        echo "User Service:          http://localhost:7070"
        echo "Regulator Service:     http://localhost:3030"
        echo "Strategic Planning:    http://localhost:8080"
        echo "KPIs Service:          http://localhost:5050"
        echo "WebSocket (Reverb):    ws://localhost:9000"

        if [ -n "$PROFILE" ]; then
            echo "API Gateway:           http://localhost:8000"
        fi

        echo ""
        echo "MongoDB:               localhost:27017"
        echo "Redis:                 localhost:6379"
        echo ""
        echo "=========================================="
        echo "Useful Commands"
        echo "=========================================="
        echo ""
        echo "View logs (all):       $DOCKER_COMPOSE logs -f"
        echo "View logs (service):   $DOCKER_COMPOSE logs -f [service-name]"
        echo "Stop all:              bash docker-down.sh"
        echo "Restart service:       $DOCKER_COMPOSE restart [service-name]"
        echo "Check status:          $DOCKER_COMPOSE ps"
        echo "Execute command:       $DOCKER_COMPOSE exec [service-name] [command]"
        echo ""
    fi
else
    log_error "Failed to start services!"
    exit 1
fi
