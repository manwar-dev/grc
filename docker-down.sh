#!/bin/bash

################################################################################
# GRC Microservices - Docker Stop Script
#
# This script stops all Docker containers for the GRC platform
################################################################################

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo "=========================================="
echo "GRC Microservices - Stopping Services"
echo "=========================================="
echo ""

# Set docker compose command
if docker compose version &> /dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

# Parse arguments
REMOVE_VOLUMES=""
REMOVE_IMAGES=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --volumes|-v)
            REMOVE_VOLUMES="-v"
            shift
            ;;
        --images)
            REMOVE_IMAGES="--rmi all"
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -v, --volumes    Remove volumes (WARNING: deletes data!)"
            echo "  --images         Remove images"
            echo "  --help           Show this help message"
            echo ""
            exit 0
            ;;
        *)
            log_warn "Unknown option: $1"
            shift
            ;;
    esac
done

if [ -n "$REMOVE_VOLUMES" ]; then
    log_warn "WARNING: This will remove all volumes and delete all data!"
    read -p "Are you sure? (yes/no): " confirmation
    if [ "$confirmation" != "yes" ]; then
        log_info "Operation cancelled."
        exit 0
    fi
fi

log_info "Stopping all services..."
$DOCKER_COMPOSE down $REMOVE_VOLUMES $REMOVE_IMAGES

if [ $? -eq 0 ]; then
    log_info "All services stopped successfully!"

    if [ -n "$REMOVE_VOLUMES" ]; then
        log_warn "All volumes have been removed. Data has been deleted."
    fi

    if [ -n "$REMOVE_IMAGES" ]; then
        log_info "All images have been removed."
    fi
else
    log_error "Failed to stop services!"
    exit 1
fi

echo ""
log_info "To start services again, run: bash docker-up.sh"
