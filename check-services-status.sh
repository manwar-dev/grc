#!/bin/bash

################################################################################
# GRC Microservices - Check Services Status Script
#
# This script checks the status of all microservices
################################################################################

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Project directory
PROJECT_DIR="/var/www/html/grc"

echo "=========================================="
echo "GRC Microservices Status"
echo "=========================================="
echo ""

# Function to check service status
check_service() {
    local service_name=$1
    local port=$2
    local pid_file="${PROJECT_DIR}/logs/${service_name}.pid"

    if [ -f "$pid_file" ]; then
        pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo -e "${service_name}: ${GREEN}RUNNING${NC} (PID: ${pid}, Port: ${port})"

            # Check if port is actually listening
            if command -v netstat &> /dev/null; then
                if netstat -tuln | grep ":${port}" > /dev/null 2>&1; then
                    echo -e "  └─ Port ${port}: ${GREEN}LISTENING${NC}"
                else
                    echo -e "  └─ Port ${port}: ${RED}NOT LISTENING${NC}"
                fi
            fi
        else
            echo -e "${service_name}: ${RED}NOT RUNNING${NC} (stale PID: ${pid})"
        fi
    else
        echo -e "${service_name}: ${RED}NOT RUNNING${NC} (no PID file)"
    fi
    echo ""
}

# Check each service
check_service "back" "9090"
check_service "notification-service" "6060"
check_service "user-service" "7070"
check_service "regulator-service" "3030"
check_service "strategic-plan-service" "8080"
check_service "kpis" "5050"
check_service "reverb" "9000"

# Check MongoDB status
echo -n "MongoDB: "
if systemctl is-active --quiet mongod; then
    echo -e "${GREEN}RUNNING${NC}"
else
    echo -e "${RED}NOT RUNNING${NC}"
fi
echo ""

# Check Nginx status
echo -n "Nginx: "
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}RUNNING${NC}"
else
    echo -e "${RED}NOT RUNNING${NC}"
fi
echo ""

echo "=========================================="
