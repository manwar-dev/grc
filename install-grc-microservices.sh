#!/bin/bash

################################################################################
# GRC Microservices Installation Script
#
# This script installs all dependencies and sets up the GRC microservices
# platform on a fresh Ubuntu/Debian-based Linux system.
#
# Services included:
#   - back (Port 9090)
#   - notification-service (Port 6060)
#   - user-service (Port 7070)
#   - regulator-service (Port 3030)
#   - strategic-plan-service
#   - kpis
#   - front (Vue.js Frontend)
#
# Requirements: Ubuntu 20.04+ or Debian 11+
# Run as: sudo bash install-grc-microservices.sh
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run this script as root or with sudo"
    exit 1
fi

# Configuration
PROJECT_DIR="/var/www/html/grc"
PHP_VERSION="8.2"
NODE_VERSION="20"
MONGODB_VERSION="7.0"

log_info "Starting GRC Microservices Installation..."
log_info "Installation Directory: $PROJECT_DIR"

################################################################################
# 1. System Update
################################################################################
log_info "Step 1/10: Updating system packages..."
apt-get update -y
apt-get upgrade -y

################################################################################
# 2. Install Essential Tools
################################################################################
log_info "Step 2/10: Installing essential tools..."
apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    build-essential

################################################################################
# 3. Install PHP 8.2+
################################################################################
log_info "Step 3/10: Installing PHP ${PHP_VERSION}..."

# Add PHP repository
add-apt-repository ppa:ondrej/php -y
apt-get update -y

# Install PHP and extensions
apt-get install -y \
    php${PHP_VERSION} \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-common \
    php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-zip \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-bcmath \
    php${PHP_VERSION}-intl \
    php${PHP_VERSION}-mongodb \
    php${PHP_VERSION}-dev

# Verify PHP installation
php -v

################################################################################
# 4. Install Composer
################################################################################
log_info "Step 4/10: Installing Composer..."

EXPECTED_SIGNATURE="$(wget -q -O - https://composer.github.io/installer.sig)"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
ACTUAL_SIGNATURE="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]; then
    log_error "Invalid Composer installer signature"
    rm composer-setup.php
    exit 1
fi

php composer-setup.php --quiet --install-dir=/usr/local/bin --filename=composer
rm composer-setup.php

composer --version

################################################################################
# 5. Install MongoDB
################################################################################
log_info "Step 5/10: Installing MongoDB ${MONGODB_VERSION}..."

# Import MongoDB public GPG key
curl -fsSL https://www.mongodb.org/static/pgp/server-${MONGODB_VERSION}.asc | \
    gpg -o /usr/share/keyrings/mongodb-server-${MONGODB_VERSION}.gpg --dearmor

# Create MongoDB list file
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-${MONGODB_VERSION}.gpg ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/${MONGODB_VERSION} multiverse" | \
    tee /etc/apt/sources.list.d/mongodb-org-${MONGODB_VERSION}.list

# Update and install MongoDB
apt-get update -y
apt-get install -y mongodb-org

# Start and enable MongoDB
systemctl start mongod
systemctl enable mongod

# Verify MongoDB installation
mongod --version

# Wait for MongoDB to be ready
sleep 5

################################################################################
# 6. Install Node.js and npm
################################################################################
log_info "Step 6/10: Installing Node.js ${NODE_VERSION}..."

# Install Node.js LTS
curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
apt-get install -y nodejs

# Verify installation
node -v
npm -v

################################################################################
# 7. Install Web Server (Nginx)
################################################################################
log_info "Step 7/10: Installing Nginx..."

apt-get install -y nginx

# Stop Nginx for now (will configure later)
systemctl stop nginx

################################################################################
# 8. Setup Laravel Microservices
################################################################################
log_info "Step 8/10: Setting up Laravel microservices..."

# List of Laravel services
SERVICES=("back" "notification-service" "user-service" "regulator-service" "strategic-plan-service" "kpis")

for SERVICE in "${SERVICES[@]}"; do
    log_info "Setting up ${SERVICE}..."

    SERVICE_PATH="${PROJECT_DIR}/${SERVICE}"

    if [ ! -d "$SERVICE_PATH" ]; then
        log_warn "Service directory not found: ${SERVICE_PATH}"
        continue
    fi

    cd "$SERVICE_PATH"

    # Install Composer dependencies
    log_info "Installing Composer dependencies for ${SERVICE}..."
    composer install --no-interaction --prefer-dist --optimize-autoloader

    # Setup environment file if .env doesn't exist
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            log_info "Creating .env file from .env.example..."
            cp .env.example .env
        fi
    fi

    # Generate application key
    if [ -f "artisan" ]; then
        log_info "Generating application key for ${SERVICE}..."
        php artisan key:generate --force

        # Generate JWT secret
        log_info "Generating JWT secret for ${SERVICE}..."
        php artisan jwt:secret --force 2>/dev/null || log_warn "JWT secret generation skipped (not installed)"
    fi

    # Set permissions
    log_info "Setting permissions for ${SERVICE}..."
    chown -R www-data:www-data "$SERVICE_PATH"
    chmod -R 755 "$SERVICE_PATH"
    chmod -R 775 "${SERVICE_PATH}/storage" 2>/dev/null || true
    chmod -R 775 "${SERVICE_PATH}/bootstrap/cache" 2>/dev/null || true

    log_info "${SERVICE} setup completed"
done

################################################################################
# 9. Setup Frontend (Vue.js)
################################################################################
log_info "Step 9/10: Setting up Frontend (Vue.js)..."

FRONT_PATH="${PROJECT_DIR}/front"

if [ -d "$FRONT_PATH" ]; then
    cd "$FRONT_PATH"

    log_info "Installing npm dependencies..."
    npm install

    log_info "Building frontend for production..."
    npm run build

    # Set permissions
    chown -R www-data:www-data "$FRONT_PATH"
    chmod -R 755 "$FRONT_PATH"

    log_info "Frontend setup completed"
else
    log_warn "Frontend directory not found: ${FRONT_PATH}"
fi

################################################################################
# 10. Create MongoDB Databases
################################################################################
log_info "Step 10/10: Creating MongoDB databases..."

# Create databases using mongosh
mongosh --eval "
    use grc;
    db.createCollection('system');
    use notification_grc_db;
    db.createCollection('notifications');
    use GRC_USER_SERVICE;
    db.createCollection('users');
    use GRC_Regulator_Service;
    db.createCollection('regulators');
    use grc-kpi;
    db.createCollection('kpis');
"

log_info "MongoDB databases created"

################################################################################
# Final Steps
################################################################################
log_info "Installation completed successfully!"
echo ""
echo "=========================================="
echo "GRC Microservices Installation Summary"
echo "=========================================="
echo ""
echo "Installed Components:"
echo "  - PHP ${PHP_VERSION}"
echo "  - Composer $(composer --version --no-ansi | head -n1)"
echo "  - MongoDB ${MONGODB_VERSION}"
echo "  - Node.js $(node -v)"
echo "  - npm $(npm -v)"
echo "  - Nginx"
echo ""
echo "Services Setup:"
echo "  - back (Port 9090)"
echo "  - notification-service (Port 6060)"
echo "  - user-service (Port 7070)"
echo "  - regulator-service (Port 3030)"
echo "  - strategic-plan-service"
echo "  - kpis"
echo "  - front (Vue.js)"
echo ""
echo "MongoDB Databases Created:"
echo "  - grc"
echo "  - notification_grc_db"
echo "  - GRC_USER_SERVICE"
echo "  - GRC_Regulator_Service"
echo "  - grc-kpi"
echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "1. Configure environment variables for each service"
echo "   Edit .env files in each service directory"
echo ""
echo "2. Update service URLs in .env files:"
echo "   - Update IP addresses from 82.29.175.67 to your server IP"
echo ""
echo "3. Run database migrations (if needed):"
echo "   cd ${PROJECT_DIR}/[service-name]"
echo "   php artisan migrate"
echo ""
echo "4. Start the services using the provided script:"
echo "   bash ${PROJECT_DIR}/start-all-services.sh"
echo ""
echo "5. Configure Nginx virtual hosts (see INSTALLATION.md)"
echo ""
echo "6. Configure SSL certificates for production"
echo ""
echo "For detailed instructions, see:"
echo "  ${PROJECT_DIR}/INSTALLATION.md"
echo ""
echo "=========================================="
