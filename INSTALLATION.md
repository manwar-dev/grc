# GRC Microservices - Complete Installation Guide

This guide provides comprehensive instructions for installing and configuring the GRC (Governance, Risk, and Compliance) microservices platform on a fresh Linux system.

## Table of Contents

- [System Requirements](#system-requirements)
- [Architecture Overview](#architecture-overview)
- [Quick Installation](#quick-installation)
- [Manual Installation](#manual-installation)
- [Service Configuration](#service-configuration)
- [Starting Services](#starting-services)
- [Nginx Configuration](#nginx-configuration)
- [Troubleshooting](#troubleshooting)
- [Production Deployment](#production-deployment)

---

## System Requirements

### Hardware Requirements
- **CPU**: 4+ cores recommended
- **RAM**: 8GB minimum, 16GB+ recommended
- **Storage**: 50GB+ available disk space
- **Network**: Stable internet connection for initial setup

### Software Requirements
- **OS**: Ubuntu 20.04+ or Debian 11+
- **PHP**: 8.1 or higher (8.2 recommended)
- **MongoDB**: 4.0+ (7.0 recommended)
- **Node.js**: 18+ (20 LTS recommended)
- **Composer**: Latest stable version
- **Nginx**: Latest stable version (or Apache as alternative)

---

## Architecture Overview

### Microservices Structure

The GRC platform consists of **7 independent services**:

| Service | Description | Port | Database |
|---------|-------------|------|----------|
| **back** | Main GRC backend service | 9090 | grc |
| **notification-service** | Notifications & real-time communications | 6060 | notification_grc_db |
| **user-service** | User management & authentication | 7070 | GRC_USER_SERVICE |
| **regulator-service** | Regulatory compliance management | 3030 | GRC_Regulator_Service |
| **strategic-plan-service** | Strategic planning module | 8080 | grc |
| **kpis** | Key Performance Indicators service | 5050 | grc-kpi |
| **front** | Vue.js 3 SPA Frontend | 80/443 | N/A |

### Technology Stack

**Backend Services:**
- Laravel 11.31
- PHP 8.1+
- MongoDB with ODM
- JWT Authentication
- Laravel Reverb (WebSocket)

**Frontend Application:**
- Vue.js 3
- Vite 6
- Pinia (State Management)
- Bootstrap 5 / Vuetify 3
- ApexCharts, Chart.js, Highcharts

---

## Quick Installation

### Option 1: Automated Installation (Recommended)

For a fresh Ubuntu/Debian system, use the automated installation script:

```bash
# Navigate to the project directory
cd /var/www/html/grc

# Make the installation script executable
chmod +x install-grc-microservices.sh

# Run the installation script as root
sudo bash install-grc-microservices.sh
```

This script will:
1. Update system packages
2. Install PHP 8.2 with all required extensions
3. Install Composer
4. Install MongoDB 7.0
5. Install Node.js 20 LTS
6. Install Nginx
7. Setup all Laravel microservices
8. Setup Vue.js frontend
9. Create MongoDB databases
10. Configure permissions

**Installation time**: 15-30 minutes depending on internet speed and system resources.

---

## Manual Installation

If you prefer to install components manually, follow these steps:

### Step 1: Update System

```bash
sudo apt-get update
sudo apt-get upgrade -y
```

### Step 2: Install Essential Tools

```bash
sudo apt-get install -y \
    curl wget git unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates gnupg \
    lsb-release build-essential
```

### Step 3: Install PHP 8.2

```bash
# Add PHP repository
sudo add-apt-repository ppa:ondrej/php -y
sudo apt-get update

# Install PHP and extensions
sudo apt-get install -y \
    php8.2 php8.2-cli php8.2-fpm \
    php8.2-common php8.2-mysql \
    php8.2-zip php8.2-gd \
    php8.2-mbstring php8.2-curl \
    php8.2-xml php8.2-bcmath \
    php8.2-intl php8.2-mongodb \
    php8.2-dev

# Verify installation
php -v
```

### Step 4: Install Composer

```bash
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer
sudo chmod +x /usr/local/bin/composer

# Verify installation
composer --version
```

### Step 5: Install MongoDB 7.0

```bash
# Import MongoDB GPG key
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
    sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor

# Add MongoDB repository
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/7.0 multiverse" | \
    sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

# Install MongoDB
sudo apt-get update
sudo apt-get install -y mongodb-org

# Start and enable MongoDB
sudo systemctl start mongod
sudo systemctl enable mongod

# Verify installation
mongod --version
```

### Step 6: Install Node.js 20 LTS

```bash
# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify installation
node -v
npm -v
```

### Step 7: Install Nginx

```bash
sudo apt-get install -y nginx

# Start and enable Nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```

### Step 8: Setup Laravel Services

For each service (back, notification-service, user-service, regulator-service, strategic-plan-service, kpis):

```bash
cd /var/www/html/grc/[service-name]

# Install dependencies
composer install --no-interaction --prefer-dist --optimize-autoloader

# Copy environment file
cp .env.example .env

# Generate application key
php artisan key:generate

# Generate JWT secret
php artisan jwt:secret

# Set permissions
sudo chown -R www-data:www-data .
sudo chmod -R 755 .
sudo chmod -R 775 storage bootstrap/cache
```

### Step 9: Setup Frontend

```bash
cd /var/www/html/grc/front

# Install dependencies
npm install

# Build for production
npm run build

# Set permissions
sudo chown -R www-data:www-data .
sudo chmod -R 755 .
```

### Step 10: Create MongoDB Databases

```bash
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
```

---

## Service Configuration

### Update Environment Variables

Each service has its own `.env` file that needs to be configured. The key settings to update:

#### 1. Server IP Address

Replace `82.29.175.67` with your actual server IP address in all `.env` files:

```bash
# Example: Update user-service
cd /var/www/html/grc/user-service
nano .env

# Find and update:
NOTIFICATION_SERVICE_URL=http://YOUR_SERVER_IP:6060/api
```

#### 2. Database Configuration

Ensure MongoDB connection settings are correct:

```env
DB_CONNECTION=mongodb
DB_HOST=127.0.0.1
DB_PORT=27017
DB_DATABASE=[service_database_name]
```

#### 3. JWT Configuration

Each service should have JWT configured:

```env
JWT_SECRET=[generated_secret]
JWT_TTL=60
JWT_REFRESH_TTL=20160
```

#### 4. Cross-Service Communication

Update service URLs in each `.env` file:

**notification-service/.env:**
```env
USER_SERVICE_URL=http://YOUR_SERVER_IP:7070/api
```

**user-service/.env:**
```env
NOTIFICATION_SERVICE_URL=http://YOUR_SERVER_IP:6060/api
```

**regulator-service/.env:**
```env
NOTIFICATION_SERVICE_URL=http://YOUR_SERVER_IP:6060/api
USER_SERVICE_URL=http://YOUR_SERVER_IP:9090/api
```

#### 5. Reverb WebSocket Configuration

**notification-service/.env:**
```env
BROADCAST_DRIVER=reverb
REVERB_APP_ID=your_app_id
REVERB_APP_KEY=your_app_key
REVERB_APP_SECRET=your_app_secret
REVERB_HOST=0.0.0.0
REVERB_PORT=9000
REVERB_SCHEME=http
```

---

## Starting Services

### Using Management Scripts

Three helper scripts are provided for service management:

#### Start All Services

```bash
cd /var/www/html/grc
chmod +x start-all-services.sh
bash start-all-services.sh
```

This will start:
- back service (port 9090)
- notification-service (port 6060)
- user-service (port 7070)
- regulator-service (port 3030)
- strategic-plan-service (port 8080)
- kpis service (port 5050)
- Reverb WebSocket server (port 9000)

#### Check Service Status

```bash
bash check-services-status.sh
```

This displays the status of all services and whether they're running.

#### Stop All Services

```bash
bash stop-all-services.sh
```

This gracefully stops all running services.

### Manual Service Start

To start services manually:

```bash
# Start a specific service
cd /var/www/html/grc/[service-name]
php artisan serve --host=0.0.0.0 --port=[PORT]

# Start Reverb WebSocket server
cd /var/www/html/grc/notification-service
php artisan reverb:start
```

### Using Systemd (Production)

For production environments, create systemd service files:

```bash
sudo nano /etc/systemd/system/grc-back.service
```

```ini
[Unit]
Description=GRC Back Service
After=network.target mongod.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/html/grc/back
ExecStart=/usr/bin/php artisan serve --host=0.0.0.0 --port=9090
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

Enable and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable grc-back
sudo systemctl start grc-back
```

Repeat for all services.

---

## Nginx Configuration

### Frontend Configuration

Create Nginx virtual host for the frontend:

```bash
sudo nano /etc/nginx/sites-available/grc-frontend
```

```nginx
server {
    listen 80;
    server_name your-domain.com;

    root /var/www/html/grc/front/dist;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # API Gateway - Proxy to backend services
    location /api/back/ {
        proxy_pass http://127.0.0.1:9090/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    location /api/notifications/ {
        proxy_pass http://127.0.0.1:6060/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    location /api/users/ {
        proxy_pass http://127.0.0.1:7070/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    location /api/regulators/ {
        proxy_pass http://127.0.0.1:3030/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    location /api/strategic-plans/ {
        proxy_pass http://127.0.0.1:8080/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    location /api/kpis/ {
        proxy_pass http://127.0.0.1:5050/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # WebSocket for Reverb
    location /app {
        proxy_pass http://127.0.0.1:9000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
    }

    access_log /var/log/nginx/grc-access.log;
    error_log /var/log/nginx/grc-error.log;
}
```

Enable the site:

```bash
sudo ln -s /etc/nginx/sites-available/grc-frontend /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### SSL Configuration (Production)

Install Certbot and obtain SSL certificate:

```bash
sudo apt-get install -y certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

---

## Troubleshooting

### Common Issues

#### 1. Services Won't Start

**Check logs:**
```bash
tail -f /var/www/html/grc/logs/[service-name].log
```

**Check if port is already in use:**
```bash
sudo netstat -tulpn | grep [PORT]
```

**Kill process on port:**
```bash
sudo fuser -k [PORT]/tcp
```

#### 2. MongoDB Connection Issues

**Check MongoDB status:**
```bash
sudo systemctl status mongod
```

**Check MongoDB logs:**
```bash
sudo tail -f /var/log/mongodb/mongod.log
```

**Test connection:**
```bash
mongosh
```

#### 3. Permission Issues

**Fix permissions:**
```bash
cd /var/www/html/grc/[service-name]
sudo chown -R www-data:www-data .
sudo chmod -R 755 .
sudo chmod -R 775 storage bootstrap/cache
```

#### 4. Composer Dependencies

**Clear Composer cache:**
```bash
composer clear-cache
composer install --no-cache
```

#### 5. Frontend Build Issues

**Clear npm cache:**
```bash
cd /var/www/html/grc/front
rm -rf node_modules package-lock.json
npm cache clean --force
npm install
```

### Service Health Checks

**Check if service is responding:**
```bash
curl http://localhost:9090/api/health
```

**Check all ports:**
```bash
sudo netstat -tulpn | grep LISTEN
```

### Log Files

Logs are stored in `/var/www/html/grc/logs/`:
- `back.log` - Main backend service
- `notification-service.log` - Notification service
- `user-service.log` - User service
- `regulator-service.log` - Regulator service
- `strategic-plan-service.log` - Strategic planning
- `kpis.log` - KPI service
- `reverb.log` - WebSocket server

**Monitor logs in real-time:**
```bash
tail -f /var/www/html/grc/logs/*.log
```

---

## Production Deployment

### Security Hardening

#### 1. Firewall Configuration

```bash
# Install UFW
sudo apt-get install -y ufw

# Allow SSH
sudo ufw allow 22/tcp

# Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow MongoDB (only from localhost)
sudo ufw deny 27017/tcp

# Enable firewall
sudo ufw enable
```

#### 2. MongoDB Security

```bash
# Enable authentication
mongosh

use admin
db.createUser({
  user: "admin",
  pwd: "strong_password_here",
  roles: [ { role: "userAdminAnyDatabase", db: "admin" } ]
})

exit
```

Update MongoDB config:
```bash
sudo nano /etc/mongod.conf
```

```yaml
security:
  authorization: enabled
```

Restart MongoDB:
```bash
sudo systemctl restart mongod
```

Update `.env` files with MongoDB credentials:
```env
DB_USERNAME=admin
DB_PASSWORD=strong_password_here
```

#### 3. PHP Security

Update PHP configuration:
```bash
sudo nano /etc/php/8.2/fpm/php.ini
```

```ini
expose_php = Off
display_errors = Off
log_errors = On
error_log = /var/log/php/error.log
```

#### 4. Nginx Security Headers

Add to Nginx configuration:
```nginx
add_header X-Frame-Options "SAMEORIGIN";
add_header X-XSS-Protection "1; mode=block";
add_header X-Content-Type-Options "nosniff";
add_header Referrer-Policy "no-referrer-when-downgrade";
add_header Content-Security-Policy "default-src 'self' https:;";
```

### Performance Optimization

#### 1. PHP-FPM Tuning

```bash
sudo nano /etc/php/8.2/fpm/pool.d/www.conf
```

```ini
pm = dynamic
pm.max_children = 50
pm.start_servers = 10
pm.min_spare_servers = 5
pm.max_spare_servers = 20
pm.max_requests = 500
```

#### 2. Laravel Optimization

For each service:
```bash
cd /var/www/html/grc/[service-name]
php artisan config:cache
php artisan route:cache
php artisan view:cache
composer install --optimize-autoloader --no-dev
```

#### 3. MongoDB Indexing

Create indexes for frequently queried fields:
```javascript
mongosh

use grc
db.users.createIndex({ email: 1 })
db.assessments.createIndex({ created_at: -1 })
```

### Monitoring

#### 1. Setup Monitoring with Supervisor

```bash
sudo apt-get install -y supervisor

# Create supervisor config for each service
sudo nano /etc/supervisor/conf.d/grc-services.conf
```

```ini
[program:grc-back]
command=/usr/bin/php /var/www/html/grc/back/artisan serve --host=0.0.0.0 --port=9090
autostart=true
autorestart=true
user=www-data
redirect_stderr=true
stdout_logfile=/var/www/html/grc/logs/back.log

[program:grc-notification]
command=/usr/bin/php /var/www/html/grc/notification-service/artisan serve --host=0.0.0.0 --port=6060
autostart=true
autorestart=true
user=www-data
redirect_stderr=true
stdout_logfile=/var/www/html/grc/logs/notification-service.log

[program:grc-reverb]
command=/usr/bin/php /var/www/html/grc/notification-service/artisan reverb:start
autostart=true
autorestart=true
user=www-data
redirect_stderr=true
stdout_logfile=/var/www/html/grc/logs/reverb.log
```

```bash
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start all
```

### Backup Strategy

#### 1. MongoDB Backup

```bash
#!/bin/bash
# /usr/local/bin/backup-grc-mongodb.sh

BACKUP_DIR="/backup/mongodb"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

mongodump --out="${BACKUP_DIR}/grc_${DATE}"

# Keep only last 7 days
find $BACKUP_DIR -type d -mtime +7 -exec rm -rf {} \;
```

Add to crontab:
```bash
sudo crontab -e
```

```cron
0 2 * * * /usr/local/bin/backup-grc-mongodb.sh
```

#### 2. Application Backup

```bash
#!/bin/bash
# /usr/local/bin/backup-grc-app.sh

BACKUP_DIR="/backup/application"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

tar -czf "${BACKUP_DIR}/grc_app_${DATE}.tar.gz" \
    /var/www/html/grc \
    --exclude='/var/www/html/grc/*/node_modules' \
    --exclude='/var/www/html/grc/*/vendor'

# Keep only last 7 days
find $BACKUP_DIR -type f -mtime +7 -delete
```

---

## Quick Reference

### Service Ports
- Back: 9090
- Notification: 6060
- User: 7070
- Regulator: 3030
- Strategic Plan: 8080
- KPIs: 5050
- Reverb: 9000
- Frontend: 80/443

### Important Directories
- Project root: `/var/www/html/grc`
- Logs: `/var/www/html/grc/logs`
- Frontend build: `/var/www/html/grc/front/dist`

### Useful Commands
```bash
# Start all services
bash /var/www/html/grc/start-all-services.sh

# Stop all services
bash /var/www/html/grc/stop-all-services.sh

# Check status
bash /var/www/html/grc/check-services-status.sh

# View logs
tail -f /var/www/html/grc/logs/*.log

# Check MongoDB
sudo systemctl status mongod

# Check Nginx
sudo systemctl status nginx
sudo nginx -t
```

---

## Support

For issues and questions:
- Check logs in `/var/www/html/grc/logs/`
- Review service status with `check-services-status.sh`
- Ensure all environment variables are correctly configured
- Verify MongoDB is running and accessible
- Check Nginx configuration with `sudo nginx -t`

---

**Installation Date**: 2025-12-16
**Version**: 1.0.0
**Platform**: GRC Microservices Architecture
