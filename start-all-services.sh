#!/bin/bash

################################################################################
# GRC Microservices - Start All Services Script
#
# This script starts all microservices on their configured ports
################################################################################

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Project directory
PROJECT_DIR="/var/www/html/grc"

# Create logs directory
mkdir -p "${PROJECT_DIR}/logs"

log_info "Starting all GRC microservices..."

# Start back service (Port 9090)
log_info "Starting back service on port 9090..."
cd "${PROJECT_DIR}/back"
nohup php artisan serve --host=0.0.0.0 --port=9090 > "${PROJECT_DIR}/logs/back.log" 2>&1 &
echo $! > "${PROJECT_DIR}/logs/back.pid"

# Start notification-service (Port 6060)
log_info "Starting notification-service on port 6060..."
cd "${PROJECT_DIR}/notification-service"
nohup php artisan serve --host=0.0.0.0 --port=6060 > "${PROJECT_DIR}/logs/notification-service.log" 2>&1 &
echo $! > "${PROJECT_DIR}/logs/notification-service.pid"

# Start user-service (Port 7070)
log_info "Starting user-service on port 7070..."
cd "${PROJECT_DIR}/user-service"
nohup php artisan serve --host=0.0.0.0 --port=7070 > "${PROJECT_DIR}/logs/user-service.log" 2>&1 &
echo $! > "${PROJECT_DIR}/logs/user-service.pid"

# Start regulator-service (Port 3030)
log_info "Starting regulator-service on port 3030..."
cd "${PROJECT_DIR}/regulator-service"
nohup php artisan serve --host=0.0.0.0 --port=3030 > "${PROJECT_DIR}/logs/regulator-service.log" 2>&1 &
echo $! > "${PROJECT_DIR}/logs/regulator-service.pid"

# Start strategic-plan-service (Port 8080)
log_info "Starting strategic-plan-service on port 8080..."
cd "${PROJECT_DIR}/strategic-plan-service"
nohup php artisan serve --host=0.0.0.0 --port=8080 > "${PROJECT_DIR}/logs/strategic-plan-service.log" 2>&1 &
echo $! > "${PROJECT_DIR}/logs/strategic-plan-service.pid"

# Start kpis service (Port 5050)
log_info "Starting kpis service on port 5050..."
cd "${PROJECT_DIR}/kpis"
nohup php artisan serve --host=0.0.0.0 --port=5050 > "${PROJECT_DIR}/logs/kpis.log" 2>&1 &
echo $! > "${PROJECT_DIR}/logs/kpis.pid"

# Start Reverb WebSocket server (Port 9000)
log_info "Starting Reverb WebSocket server on port 9000..."
cd "${PROJECT_DIR}/notification-service"
nohup php artisan reverb:start > "${PROJECT_DIR}/logs/reverb.log" 2>&1 &
echo $! > "${PROJECT_DIR}/logs/reverb.pid"

# Wait a moment for services to start
sleep 3

echo ""
echo "=========================================="
echo "All services started!"
echo "=========================================="
echo ""
echo "Service Status:"
echo "  - back:                    http://localhost:9090"
echo "  - notification-service:    http://localhost:6060"
echo "  - user-service:            http://localhost:7070"
echo "  - regulator-service:       http://localhost:3030"
echo "  - strategic-plan-service:  http://localhost:8080"
echo "  - kpis:                    http://localhost:5050"
echo "  - Reverb WebSocket:        ws://localhost:9000"
echo ""
echo "Logs location: ${PROJECT_DIR}/logs/"
echo "PID files: ${PROJECT_DIR}/logs/*.pid"
echo ""
echo "To stop all services, run:"
echo "  bash ${PROJECT_DIR}/stop-all-services.sh"
echo ""
echo "To check service status:"
echo "  bash ${PROJECT_DIR}/check-services-status.sh"
echo ""
