# GRC Microservices Platform - Installation Package

Complete installation scripts and documentation for deploying the GRC (Governance, Risk, and Compliance) microservices platform on a fresh Linux server.

## Overview

This installation package provides everything needed to set up a complete GRC microservices architecture including:

- **6 Laravel-based backend microservices**
- **1 Vue.js 3 frontend application**
- **MongoDB 7.0 database**
- **PHP 8.2 runtime**
- **Node.js 20 LTS**
- **Nginx web server**
- **JWT authentication**
- **Real-time WebSocket communication**

## Files in This Package

### Installation Scripts

| File | Description |
|------|-------------|
| `install-grc-microservices.sh` | Main installation script - installs all dependencies and sets up services |
| `start-all-services.sh` | Starts all microservices in the background |
| `stop-all-services.sh` | Gracefully stops all running services |
| `check-services-status.sh` | Displays status of all services and system components |
| `configure-server-ip.sh` | Updates service URLs with your server IP address |

### Documentation

| File | Description |
|------|-------------|
| `INSTALLATION.md` | Complete installation and configuration guide (comprehensive) |
| `QUICK-START.md` | Quick start guide for fast setup (condensed) |
| `README-INSTALLATION.md` | This file - overview and getting started |
| `ASSESSMENT_RISK_TRACKING_README.md` | Feature-specific documentation for assessment/risk tracking |

## Quick Installation

For the fastest setup, follow these steps:

### Step 1: Run the Installer

```bash
cd /var/www/html/grc
sudo bash install-grc-microservices.sh
```

This automated script will install:
- PHP 8.2 with all required extensions
- Composer (PHP dependency manager)
- MongoDB 7.0
- Node.js 20 LTS
- Nginx
- All service dependencies

**Time required**: 15-30 minutes

### Step 2: Configure Server IP

```bash
bash configure-server-ip.sh
```

Enter your server IP address when prompted. This updates all service URLs.

### Step 3: Start Services

```bash
bash start-all-services.sh
```

This starts all 6 backend services plus the WebSocket server.

### Step 4: Verify

```bash
bash check-services-status.sh
```

All services should show "RUNNING" status.

## Architecture

### Services and Ports

```
┌─────────────────────────────────────────────────────────┐
│                  GRC Microservices Platform             │
└─────────────────────────────────────────────────────────┘

Backend Services (Laravel 11):
├─ back                      → Port 9090  (Main GRC backend)
├─ notification-service      → Port 6060  (Notifications & real-time)
├─ user-service              → Port 7070  (User management & auth)
├─ regulator-service         → Port 3030  (Regulatory compliance)
├─ strategic-plan-service    → Port 8080  (Strategic planning)
└─ kpis                      → Port 5050  (KPI metrics)

Real-time Communication:
└─ Laravel Reverb            → Port 9000  (WebSocket server)

Frontend:
└─ Vue.js 3 SPA              → Port 80/443 (Web interface)

Database:
└─ MongoDB 7.0               → Port 27017 (Internal only)
   ├─ grc
   ├─ notification_grc_db
   ├─ GRC_USER_SERVICE
   ├─ GRC_Regulator_Service
   └─ grc-kpi
```

### Technology Stack

**Backend:**
- Laravel 11.31
- PHP 8.2
- MongoDB with ODM (Object-Document Mapper)
- JWT Authentication (tymon/jwt-auth)
- Laravel Reverb (WebSocket)
- DomPDF (PDF generation)
- Maatwebsite/Excel (Excel export)

**Frontend:**
- Vue.js 3
- Vite 6 (Build tool)
- Pinia (State management)
- Vue Router 4
- Bootstrap 5 / Vuetify 3
- ApexCharts, Chart.js, Highcharts
- CKEditor 5
- Laravel Echo + Pusher (Real-time)

## Service Management

### Starting Services

```bash
# Start all services
bash start-all-services.sh

# Start a specific service manually
cd [service-name]
php artisan serve --host=0.0.0.0 --port=[PORT]

# Start WebSocket server
cd notification-service
php artisan reverb:start
```

### Stopping Services

```bash
# Stop all services
bash stop-all-services.sh

# Stop a specific service (get PID from logs/)
kill $(cat logs/[service-name].pid)
```

### Checking Status

```bash
# Check all services
bash check-services-status.sh

# Check if a port is listening
netstat -tuln | grep [PORT]

# Check MongoDB
sudo systemctl status mongod

# Check Nginx
sudo systemctl status nginx
```

### Viewing Logs

```bash
# View all logs in real-time
tail -f logs/*.log

# View specific service log
tail -f logs/[service-name].log

# View last 100 lines
tail -n 100 logs/[service-name].log
```

## Configuration

### Environment Files

Each service has a `.env` file with its configuration:

```
/var/www/html/grc/
├── back/.env
├── notification-service/.env
├── user-service/.env
├── regulator-service/.env
├── strategic-plan-service/.env
└── kpis/.env
```

### Key Configuration Items

**Database Connection:**
```env
DB_CONNECTION=mongodb
DB_HOST=127.0.0.1
DB_PORT=27017
DB_DATABASE=[database_name]
```

**JWT Configuration:**
```env
JWT_SECRET=[auto-generated]
JWT_TTL=60
JWT_REFRESH_TTL=20160
```

**Service URLs:**
```env
USER_SERVICE_URL=http://YOUR_IP:7070/api
NOTIFICATION_SERVICE_URL=http://YOUR_IP:6060/api
```

**WebSocket (Reverb):**
```env
BROADCAST_DRIVER=reverb
REVERB_HOST=0.0.0.0
REVERB_PORT=9000
```

## System Requirements

### Minimum Requirements
- **OS**: Ubuntu 20.04+ or Debian 11+
- **CPU**: 4 cores
- **RAM**: 8GB
- **Storage**: 50GB
- **Network**: Stable internet connection

### Recommended for Production
- **CPU**: 8+ cores
- **RAM**: 16GB+
- **Storage**: 100GB+ SSD
- **Network**: 1Gbps

## Firewall Configuration

```bash
# Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow SSH
sudo ufw allow 22/tcp

# Deny direct access to services (access via Nginx proxy)
sudo ufw deny 9090/tcp
sudo ufw deny 6060/tcp
sudo ufw deny 7070/tcp
sudo ufw deny 3030/tcp
sudo ufw deny 8080/tcp
sudo ufw deny 5050/tcp

# Deny MongoDB external access
sudo ufw deny 27017/tcp

# Enable firewall
sudo ufw enable
```

## Production Considerations

### 1. Use Systemd Services

Instead of the start/stop scripts, create systemd services for automatic startup and restart on failure.

See `INSTALLATION.md` for systemd configuration examples.

### 2. Setup Nginx Reverse Proxy

Configure Nginx to proxy requests to backend services and serve the frontend.

See `INSTALLATION.md` for Nginx configuration.

### 3. Enable SSL/HTTPS

Use Let's Encrypt for free SSL certificates:

```bash
sudo apt-get install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

### 4. Enable MongoDB Authentication

See `INSTALLATION.md` for MongoDB security configuration.

### 5. Setup Monitoring

Use Supervisor for process monitoring:

```bash
sudo apt-get install supervisor
```

See `INSTALLATION.md` for Supervisor configuration.

### 6. Configure Backups

Setup automated backups for:
- MongoDB databases
- Application files
- Configuration files

See `INSTALLATION.md` for backup scripts.

## Troubleshooting

### Services Won't Start

1. Check if ports are already in use:
```bash
sudo netstat -tulpn | grep [PORT]
```

2. Check logs for errors:
```bash
tail -f logs/[service-name].log
```

3. Verify MongoDB is running:
```bash
sudo systemctl status mongod
```

### MongoDB Connection Issues

1. Check MongoDB status:
```bash
sudo systemctl status mongod
```

2. Test connection:
```bash
mongosh
```

3. Check MongoDB logs:
```bash
sudo tail -f /var/log/mongodb/mongod.log
```

### Permission Errors

Fix permissions for a service:
```bash
cd /var/www/html/grc/[service-name]
sudo chown -R www-data:www-data .
sudo chmod -R 755 .
sudo chmod -R 775 storage bootstrap/cache
```

### Frontend Build Issues

```bash
cd /var/www/html/grc/front
rm -rf node_modules package-lock.json
npm cache clean --force
npm install
npm run build
```

## Accessing the Application

### Backend Services

Direct access to services (development only):
- Main Backend: `http://YOUR_IP:9090`
- Notification Service: `http://YOUR_IP:6060`
- User Service: `http://YOUR_IP:7070`
- Regulator Service: `http://YOUR_IP:3030`
- Strategic Planning: `http://YOUR_IP:8080`
- KPIs: `http://YOUR_IP:5050`

### Frontend

After configuring Nginx:
- HTTP: `http://YOUR_IP` or `http://your-domain.com`
- HTTPS: `https://your-domain.com` (after SSL setup)

## Documentation Links

- **Complete Installation Guide**: `INSTALLATION.md` - Comprehensive guide with all details
- **Quick Start Guide**: `QUICK-START.md` - Fast setup for experienced users
- **Feature Documentation**: `ASSESSMENT_RISK_TRACKING_README.md` - Assessment and risk tracking features

## Support and Maintenance

### Regular Maintenance

1. **Update system packages**:
```bash
sudo apt-get update && sudo apt-get upgrade
```

2. **Update Composer dependencies**:
```bash
cd /var/www/html/grc/[service-name]
composer update
```

3. **Update npm packages**:
```bash
cd /var/www/html/grc/front
npm update
```

4. **Clear Laravel caches**:
```bash
php artisan cache:clear
php artisan config:clear
php artisan route:clear
php artisan view:clear
```

### Logs Location

- Service logs: `/var/www/html/grc/logs/`
- MongoDB logs: `/var/log/mongodb/mongod.log`
- Nginx logs: `/var/log/nginx/`
- PHP-FPM logs: `/var/log/php8.2-fpm.log`

### Health Checks

Create a cron job to monitor services:

```bash
# Add to crontab
*/5 * * * * /var/www/html/grc/check-services-status.sh > /dev/null 2>&1
```

## Version Information

- **Platform**: GRC Microservices
- **Version**: 1.0.0
- **Installation Package Date**: 2025-12-16
- **Laravel Version**: 11.31
- **PHP Version**: 8.2+
- **MongoDB Version**: 7.0
- **Node.js Version**: 20 LTS
- **Vue.js Version**: 3.x

## License and Credits

GRC Platform - Enterprise Governance, Risk, and Compliance System

For additional support and detailed documentation, refer to:
- INSTALLATION.md
- QUICK-START.md
- Laravel Documentation: https://laravel.com/docs
- Vue.js Documentation: https://vuejs.org/guide
- MongoDB Documentation: https://docs.mongodb.com

---

**Ready to install?** Run: `sudo bash install-grc-microservices.sh`
