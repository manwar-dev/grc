#!/bin/bash

################################################################################
# GRC Microservices - Docker Build Script
#
# This script builds all Docker images for the GRC platform
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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

echo "=========================================="
echo "GRC Microservices - Docker Build"
echo "=========================================="
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if docker-compose is installed
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    log_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Set docker compose command
if docker compose version &> /dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

log_info "Using Docker Compose: $DOCKER_COMPOSE"
echo ""

# Parse arguments
BUILD_ALL=true
BUILD_SERVICES=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --service)
            BUILD_ALL=false
            BUILD_SERVICES+=("$2")
            shift 2
            ;;
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        --pull)
            PULL="--pull"
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --service SERVICE    Build specific service (can be used multiple times)"
            echo "  --no-cache           Build without using cache"
            echo "  --pull               Always pull newer versions of base images"
            echo "  --help               Show this help message"
            echo ""
            echo "Services:"
            echo "  back, notification-service, user-service, regulator-service,"
            echo "  strategic-plan-service, kpis, frontend, mongodb, redis"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Build all services"
            echo "  $0 --service back                     # Build only back service"
            echo "  $0 --service back --service frontend  # Build back and frontend"
            echo "  $0 --no-cache                         # Build all without cache"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    log_warn ".env file not found. Creating from .env.docker..."
    cp .env.docker .env
    log_info ".env file created. Please review and update if needed."
fi

# Build services
if [ "$BUILD_ALL" = true ]; then
    log_step "Building all services..."
    echo ""

    $DOCKER_COMPOSE build $NO_CACHE $PULL

    if [ $? -eq 0 ]; then
        log_info "All services built successfully!"
    else
        log_error "Build failed!"
        exit 1
    fi
else
    log_step "Building selected services: ${BUILD_SERVICES[*]}"
    echo ""

    for service in "${BUILD_SERVICES[@]}"; do
        log_info "Building $service..."
        $DOCKER_COMPOSE build $NO_CACHE $PULL "$service"

        if [ $? -eq 0 ]; then
            log_info "$service built successfully!"
        else
            log_error "Build failed for $service!"
            exit 1
        fi
    done
fi

echo ""
echo "=========================================="
echo "Build Summary"
echo "=========================================="
echo ""

# List built images
log_info "Built images:"
docker images | grep "grc-" | awk '{print "  - " $1 ":" $2 " (" $7 " " $8 ")"}'

echo ""
echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo ""
echo "1. Review .env configuration:"
echo "   nano .env"
echo ""
echo "2. Start all services:"
echo "   bash docker-up.sh"
echo ""
echo "3. Or start with docker-compose directly:"
echo "   $DOCKER_COMPOSE up -d"
echo ""
echo "4. Check service status:"
echo "   $DOCKER_COMPOSE ps"
echo ""
echo "5. View logs:"
echo "   $DOCKER_COMPOSE logs -f"
echo ""
