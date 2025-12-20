#!/bin/bash

################################################################################
# GRC Microservices - Server IP Configuration Script
#
# This script updates all service URLs in .env files with your actual server IP
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

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Project directory
PROJECT_DIR="/var/www/html/grc"

echo "=========================================="
echo "GRC Server IP Configuration"
echo "=========================================="
echo ""

# Get current IP
CURRENT_IP=$(hostname -I | awk '{print $1}')
log_info "Detected current server IP: $CURRENT_IP"
echo ""

# Ask for IP address
read -p "Enter your server IP address (or press Enter to use $CURRENT_IP): " SERVER_IP

if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$CURRENT_IP
fi

log_info "Using server IP: $SERVER_IP"
echo ""

# Old IP to replace
OLD_IP="82.29.175.67"

log_info "Updating service URLs from $OLD_IP to $SERVER_IP..."
echo ""

# List of services with .env files
SERVICES=("back" "notification-service" "user-service" "regulator-service" "strategic-plan-service" "kpis")

for SERVICE in "${SERVICES[@]}"; do
    ENV_FILE="${PROJECT_DIR}/${SERVICE}/.env"

    if [ -f "$ENV_FILE" ]; then
        log_info "Updating ${SERVICE}/.env..."

        # Backup original file
        cp "$ENV_FILE" "${ENV_FILE}.backup"

        # Replace old IP with new IP
        sed -i "s/${OLD_IP}/${SERVER_IP}/g" "$ENV_FILE"

        # Update localhost to actual IP if needed
        sed -i "s|http://localhost:|http://${SERVER_IP}:|g" "$ENV_FILE"
        sed -i "s|http://127.0.0.1:|http://${SERVER_IP}:|g" "$ENV_FILE"

        log_info "  ✓ Updated ${SERVICE}"
    else
        log_warn "  ✗ ${ENV_FILE} not found"
    fi
done

echo ""
log_info "Configuration completed!"
echo ""
echo "=========================================="
echo "Updated URLs:"
echo "=========================================="
echo ""
echo "Main Backend:        http://${SERVER_IP}:9090"
echo "Notification:        http://${SERVER_IP}:6060"
echo "User Service:        http://${SERVER_IP}:7070"
echo "Regulator:           http://${SERVER_IP}:3030"
echo "Strategic Planning:  http://${SERVER_IP}:8080"
echo "KPIs:                http://${SERVER_IP}:5050"
echo "WebSocket (Reverb):  ws://${SERVER_IP}:9000"
echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "1. Restart all services:"
echo "   bash ${PROJECT_DIR}/stop-all-services.sh"
echo "   bash ${PROJECT_DIR}/start-all-services.sh"
echo ""
echo "2. Verify services are running:"
echo "   bash ${PROJECT_DIR}/check-services-status.sh"
echo ""
echo "Backup files created with .backup extension"
echo ""
