#!/bin/bash

################################################################################
# GRC Microservices - Stop All Services Script
#
# This script stops all running microservices
################################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Project directory
PROJECT_DIR="/var/www/html/grc"

log_info "Stopping all GRC microservices..."

# List of services
SERVICES=("back" "notification-service" "user-service" "regulator-service" "strategic-plan-service" "kpis" "reverb")

for SERVICE in "${SERVICES[@]}"; do
    PID_FILE="${PROJECT_DIR}/logs/${SERVICE}.pid"

    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")

        if ps -p "$PID" > /dev/null 2>&1; then
            log_info "Stopping ${SERVICE} (PID: ${PID})..."
            kill "$PID"
            rm "$PID_FILE"
        else
            log_error "${SERVICE} is not running (PID ${PID} not found)"
            rm "$PID_FILE"
        fi
    else
        log_info "No PID file found for ${SERVICE}"
    fi
done

# Also kill any remaining artisan serve processes
log_info "Cleaning up any remaining PHP artisan processes..."
pkill -f "artisan serve" 2>/dev/null || true
pkill -f "artisan reverb:start" 2>/dev/null || true

echo ""
echo "All services stopped!"
