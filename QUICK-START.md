# GRC Microservices - Quick Start Guide

This is a condensed guide to get the GRC platform up and running quickly.

## Prerequisites

- Fresh Ubuntu 20.04+ or Debian 11+ installation
- Root or sudo access
- Minimum 8GB RAM, 4 CPU cores

## Installation (5 Steps)

### 1. Run Installation Script

```bash
cd /var/www/html/grc
chmod +x install-grc-microservices.sh
sudo bash install-grc-microservices.sh
```

Wait 15-30 minutes for completion.

### 2. Configure Services

Update IP addresses in all `.env` files (replace `82.29.175.67` with your server IP):

```bash
# Quick find and replace for all services
find /var/www/html/grc -name ".env" -type f -exec sed -i 's/82.29.175.67/YOUR_SERVER_IP/g' {} \;
```

### 3. Start All Services

```bash
cd /var/www/html/grc
chmod +x start-all-services.sh stop-all-services.sh check-services-status.sh
bash start-all-services.sh
```

### 4. Check Status

```bash
bash check-services-status.sh
```

All services should show "RUNNING".

### 5. Access the Application

Open your browser:
```
http://YOUR_SERVER_IP:9090    (Main Backend)
http://YOUR_SERVER_IP          (Frontend via Nginx)
```

## Service Ports

| Service | Port |
|---------|------|
| back | 9090 |
| notification-service | 6060 |
| user-service | 7070 |
| regulator-service | 3030 |
| strategic-plan-service | 8080 |
| kpis | 5050 |
| reverb (WebSocket) | 9000 |

## Common Commands

```bash
# Start services
bash start-all-services.sh

# Stop services
bash stop-all-services.sh

# Check status
bash check-services-status.sh

# View logs
tail -f logs/*.log

# Restart a service
bash stop-all-services.sh
bash start-all-services.sh
```

## Troubleshooting

### Services won't start
```bash
# Check if ports are in use
sudo netstat -tulpn | grep -E '9090|6060|7070|3030|8080|5050|9000'

# Check logs
tail -f logs/[service-name].log
```

### MongoDB issues
```bash
# Check MongoDB status
sudo systemctl status mongod

# Restart MongoDB
sudo systemctl restart mongod

# Test connection
mongosh
```

### Permission errors
```bash
# Fix permissions for a service
cd /var/www/html/grc/[service-name]
sudo chown -R www-data:www-data .
sudo chmod -R 775 storage bootstrap/cache
```

## Next Steps

1. **Configure Nginx** - See INSTALLATION.md for reverse proxy setup
2. **Setup SSL** - Use Let's Encrypt for HTTPS
3. **Enable Monitoring** - Setup Supervisor for automatic restarts
4. **Configure Backups** - Schedule MongoDB and application backups

## Full Documentation

For detailed information, see:
- **INSTALLATION.md** - Complete installation and configuration guide
- **ASSESSMENT_RISK_TRACKING_README.md** - Feature documentation

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Frontend (Vue.js)                    │
│                      Port 80/443                        │
└────────────────────┬────────────────────────────────────┘
                     │
                     ├──────────┐
                     │          │
┌────────────────────▼──┐  ┌───▼──────────────────────┐
│   Back Service        │  │  Notification Service    │
│   Port: 9090          │  │  Port: 6060              │
│   DB: grc             │  │  DB: notification_grc_db │
└───────────────────────┘  └──────────────────────────┘
                     │
         ┌───────────┼───────────┐
         │           │           │
┌────────▼──────┐ ┌──▼─────────┐ ┌──▼──────────────┐
│ User Service  │ │ Regulator  │ │ Strategic Plan  │
│ Port: 7070    │ │ Port: 3030 │ │ Port: 8080      │
└───────────────┘ └────────────┘ └─────────────────┘
         │
         │
┌────────▼──────────┐  ┌──────────────────┐
│  KPIs Service     │  │ Reverb WebSocket │
│  Port: 5050       │  │ Port: 9000       │
└───────────────────┘  └──────────────────┘
         │
         │
┌────────▼─────────────────────────────────┐
│           MongoDB 7.0                    │
│  - grc                                   │
│  - notification_grc_db                   │
│  - GRC_USER_SERVICE                      │
│  - GRC_Regulator_Service                 │
│  - grc-kpi                               │
└──────────────────────────────────────────┘
```

## Support

Check service logs:
```bash
ls -la /var/www/html/grc/logs/
tail -f /var/www/html/grc/logs/[service-name].log
```

For detailed troubleshooting, refer to INSTALLATION.md
