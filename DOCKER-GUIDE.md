# GRC Microservices - Docker Deployment Guide

Complete guide for deploying the GRC platform using Docker and Docker Compose.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Configuration](#configuration)
- [Building Images](#building-images)
- [Running Services](#running-services)
- [Managing Services](#managing-services)
- [Troubleshooting](#troubleshooting)
- [Production Deployment](#production-deployment)
- [Advanced Topics](#advanced-topics)

---

## Overview

This Docker setup provides a complete containerized environment for the GRC microservices platform:

- **6 Laravel backend microservices** (PHP 8.2 + MongoDB)
- **1 Vue.js frontend** (production-ready build)
- **MongoDB 7.0** (with automatic initialization)
- **Redis 7** (for caching and queues)
- **Nginx API Gateway** (optional, for production)

All services are fully configured with health checks, automatic restarts, and persistent volumes.

---

## Prerequisites

### System Requirements

**Minimum:**
- Docker 20.10+
- Docker Compose 2.0+
- 8GB RAM
- 4 CPU cores
- 50GB disk space

**Recommended:**
- Docker 24.0+
- Docker Compose 2.20+
- 16GB RAM
- 8 CPU cores
- 100GB SSD

### Install Docker

**Ubuntu/Debian:**
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt-get update
sudo apt-get install docker-compose-plugin
```

**Verify Installation:**
```bash
docker --version
docker compose version
```

---

## Quick Start

### 1. Clone or Navigate to Project

```bash
cd /var/www/html/grc
```

### 2. Create Environment File

```bash
cp .env.docker .env
```

Edit `.env` to customize configuration (MongoDB passwords, service URLs, etc.).

### 3. Build Images

```bash
bash docker-build.sh
```

This builds all Docker images. Takes 10-15 minutes on first run.

### 4. Start Services

```bash
bash docker-up.sh
```

All services will start in detached mode (background).

### 5. Verify Services

```bash
bash docker-status.sh
```

All containers should show "running" status.

### 6. Access Application

- **Frontend**: http://localhost
- **Main Backend**: http://localhost:9090
- **User Service**: http://localhost:7070
- **Notification Service**: http://localhost:6060
- **Regulator Service**: http://localhost:3030
- **Strategic Planning**: http://localhost:8080
- **KPIs Service**: http://localhost:5050

---

## Architecture

### Container Structure

```
┌─────────────────────────────────────────────────────┐
│              Docker Network (grc-network)           │
│              172.25.0.0/16                          │
│                                                     │
│  ┌──────────────────────────────────────────────┐ │
│  │  Frontend (Nginx + Vue.js)                   │ │
│  │  Port: 80, 443                               │ │
│  └────────────┬─────────────────────────────────┘ │
│               │                                     │
│  ┌────────────▼─────────────────────────────────┐ │
│  │  API Gateway (Nginx)                         │ │
│  │  Port: 8000 (production only)                │ │
│  └────────────┬─────────────────────────────────┘ │
│               │                                     │
│         ┌─────┴──────┬──────────┬──────────┐      │
│         │            │          │          │      │
│  ┌──────▼───┐ ┌─────▼────┐ ┌──▼─────┐ ┌──▼────┐ │
│  │  Back    │ │  User    │ │ Notif  │ │  Reg  │ │
│  │  :9090   │ │  :7070   │ │ :6060  │ │ :3030 │ │
│  └──────────┘ └──────────┘ └────────┘ └───────┘ │
│       │            │           │ :9000      │     │
│       │            │           │(WebSocket) │     │
│  ┌────▼─────┐ ┌───▼──────┐   │            │     │
│  │Strategic │ │  KPIs    │   │            │     │
│  │  :8080   │ │  :5050   │   │            │     │
│  └──────────┘ └──────────┘   │            │     │
│       │            │           │            │     │
│  ┌────▼────────────▼───────────▼────────────▼──┐ │
│  │           MongoDB 7.0                        │ │
│  │           Port: 27017                        │ │
│  │  Databases: grc, notification_grc_db,       │ │
│  │  GRC_USER_SERVICE, GRC_Regulator_Service,   │ │
│  │  grc-kpi                                     │ │
│  └──────────────────────────────────────────────┘ │
│                                                     │
│  ┌──────────────────────────────────────────────┐ │
│  │           Redis 7                            │ │
│  │           Port: 6379                         │ │
│  │  (Cache, Sessions, Queues)                   │ │
│  └──────────────────────────────────────────────┘ │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Services Overview

| Service | Container | Image | Ports | Dependencies |
|---------|-----------|-------|-------|--------------|
| MongoDB | grc-mongodb | mongo:7.0 | 27017 | - |
| Redis | grc-redis | redis:7-alpine | 6379 | - |
| Back | grc-back | Custom | 9090:80 | mongodb, redis |
| Notification | grc-notification | Custom | 6060:80, 9000 | mongodb, redis |
| User | grc-user | Custom | 7070:80 | mongodb, redis |
| Regulator | grc-regulator | Custom | 3030:80 | mongodb, redis |
| Strategic | grc-strategic | Custom | 8080:80 | mongodb, redis |
| KPIs | grc-kpis | Custom | 5050:80 | mongodb, redis |
| Frontend | grc-frontend | Custom | 80, 443 | All backends |
| Gateway | grc-gateway | nginx:alpine | 8000:80 | All backends |

---

## Configuration

### Environment Variables

The `.env` file controls all configuration:

#### MongoDB Configuration

```env
MONGO_ROOT_USER=admin
MONGO_ROOT_PASSWORD=admin123
MONGO_APP_USER=grc_user
MONGO_APP_PASSWORD=grc_password_2025
```

#### Application Settings

```env
APP_ENV=production
APP_DEBUG=false
JWT_TTL=60
JWT_REFRESH_TTL=20160
```

#### Service URLs

```env
VITE_API_BASE_URL=http://localhost:8000
VITE_USER_SERVICE_URL=http://localhost:8000
VITE_NOTIFICATION_SERVICE_URL=http://localhost:8000
VITE_WS_URL=ws://localhost:9000
```

#### Reverb WebSocket

```env
BROADCAST_DRIVER=reverb
REVERB_APP_KEY=eczq6mqamfp4rxpldpti
REVERB_APP_SECRET=your-secret-key-here
REVERB_PORT=9000
```

### Volume Mounts

Persistent data is stored in Docker volumes:

- `mongodb_data` - MongoDB database files
- `mongodb_config` - MongoDB configuration
- `redis_data` - Redis data
- `back_storage` - Back service uploads/cache
- `notification_storage` - Notification service data
- `user_storage` - User service data
- `regulator_storage` - Regulator service data
- `strategic_storage` - Strategic planning data
- `kpis_storage` - KPIs service data

To list volumes:
```bash
docker volume ls | grep grc
```

---

## Building Images

### Build All Services

```bash
bash docker-build.sh
```

### Build Specific Service

```bash
bash docker-build.sh --service back
bash docker-build.sh --service frontend
```

### Build Without Cache

```bash
bash docker-build.sh --no-cache
```

### Build and Pull Latest Base Images

```bash
bash docker-build.sh --pull
```

### Using Docker Compose Directly

```bash
# Build all
docker compose build

# Build specific service
docker compose build back

# Build without cache
docker compose build --no-cache

# Pull and build
docker compose build --pull
```

---

## Running Services

### Start All Services

```bash
bash docker-up.sh
```

Services start in detached mode (background).

### Start in Foreground (with logs)

```bash
bash docker-up.sh --foreground
```

### Start with Production Profile

```bash
bash docker-up.sh --production
```

This includes the Nginx API Gateway.

### Start and Rebuild

```bash
bash docker-up.sh --build
```

### Using Docker Compose Directly

```bash
# Start all services
docker compose up -d

# Start specific service
docker compose up -d back

# Start with logs
docker compose up

# Start production profile
docker compose --profile production up -d
```

---

## Managing Services

### Check Status

```bash
bash docker-status.sh
```

Shows container status, health, and resource usage.

### View Logs

```bash
# All services
bash docker-logs.sh

# Specific service
bash docker-logs.sh --service back

# Without following
bash docker-logs.sh --service back --no-follow

# Last 50 lines
bash docker-logs.sh --tail 50
```

### Stop Services

```bash
bash docker-down.sh
```

### Stop and Remove Volumes (⚠️ Deletes Data)

```bash
bash docker-down.sh --volumes
```

### Restart a Service

```bash
docker compose restart back
docker compose restart user-service
```

### Execute Commands in Container

```bash
# Access bash shell
docker compose exec back bash

# Run artisan command
docker compose exec back php artisan tinker

# Check PHP version
docker compose exec back php -v

# View environment variables
docker compose exec back env
```

### Scale Services (if needed)

```bash
# Run multiple instances of a service
docker compose up -d --scale back=3
```

---

## Troubleshooting

### Services Won't Start

**Check logs:**
```bash
bash docker-logs.sh --service [service-name]
```

**Check Docker daemon:**
```bash
sudo systemctl status docker
```

**Check available resources:**
```bash
docker system df
```

### MongoDB Connection Issues

**Check MongoDB status:**
```bash
docker compose exec mongodb mongosh --eval "db.adminCommand('ping')"
```

**Verify credentials:**
```bash
docker compose exec mongodb mongosh -u admin -p admin123 --authenticationDatabase admin
```

**Check logs:**
```bash
bash docker-logs.sh --service mongodb
```

### Port Already in Use

**Find process using port:**
```bash
sudo lsof -i :9090
sudo netstat -tulpn | grep 9090
```

**Kill process:**
```bash
sudo fuser -k 9090/tcp
```

**Or change port in docker-compose.yml:**
```yaml
services:
  back:
    ports:
      - "9091:80"  # Changed from 9090
```

### Container Keeps Restarting

**Check container logs:**
```bash
docker logs grc-back --tail 100
```

**Inspect container:**
```bash
docker inspect grc-back
```

**Check health:**
```bash
docker inspect --format='{{.State.Health.Status}}' grc-back
```

### Out of Disk Space

**Check disk usage:**
```bash
docker system df
```

**Clean up:**
```bash
# Remove unused containers
docker container prune -f

# Remove unused images
docker image prune -a -f

# Remove unused volumes
docker volume prune -f

# Clean everything
docker system prune -a --volumes -f
```

### Permission Issues

**Fix volume permissions:**
```bash
docker compose exec back chown -R www-data:www-data /var/www/html
docker compose exec back chmod -R 775 /var/www/html/storage
```

### Service Not Responding

**Check if service is healthy:**
```bash
docker compose ps
```

**Restart service:**
```bash
docker compose restart back
```

**Rebuild and restart:**
```bash
docker compose up -d --build back
```

### View Container Resource Usage

```bash
docker stats
```

---

## Production Deployment

### 1. Secure Configuration

**Update .env file:**
```env
APP_ENV=production
APP_DEBUG=false
MONGO_ROOT_PASSWORD=strong_password_here
MONGO_APP_PASSWORD=strong_password_here
```

**Generate secure keys:**
```bash
# Generate random passwords
openssl rand -base64 32
```

### 2. Use Production Profile

```bash
docker compose --profile production up -d
```

This starts the Nginx API Gateway on port 8000.

### 3. Configure SSL

**Install Certbot in gateway container:**
```bash
docker compose exec nginx-gateway sh
apk add certbot certbot-nginx
certbot --nginx -d your-domain.com
```

**Or use a reverse proxy (recommended):**
- Traefik
- Nginx Proxy Manager
- Caddy

### 4. Resource Limits

Add to `docker-compose.yml`:

```yaml
services:
  back:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 512M
```

### 5. Health Monitoring

**Setup monitoring:**
- Prometheus + Grafana
- Docker Health Checks
- Uptime monitoring (UptimeRobot, etc.)

### 6. Backup Strategy

**Automated backups:**
```bash
# Backup MongoDB
docker compose exec mongodb mongodump --out=/backup/$(date +%Y%m%d)

# Copy from container
docker cp grc-mongodb:/backup ./backups

# Backup volumes
docker run --rm \
  -v grc_mongodb_data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/mongodb-$(date +%Y%m%d).tar.gz /data
```

### 7. Log Management

**Configure log rotation:**
Edit `/etc/docker/daemon.json`:
```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

**Restart Docker:**
```bash
sudo systemctl restart docker
```

### 8. Network Security

**Firewall rules:**
```bash
# Only allow necessary ports
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp
sudo ufw enable

# Deny direct access to service ports
sudo ufw deny 9090/tcp
sudo ufw deny 6060/tcp
# etc.
```

---

## Advanced Topics

### Custom Networks

Services communicate via `grc-network` (172.25.0.0/16).

**Create additional networks:**
```yaml
networks:
  grc-internal:
    driver: bridge
    internal: true
  grc-public:
    driver: bridge
```

### Using External MongoDB

```yaml
services:
  back:
    environment:
      - DB_HOST=external-mongodb.example.com
      - DB_PORT=27017
# Remove mongodb service
```

### Development Mode

Mount source code for live reloading:

```yaml
services:
  back:
    volumes:
      - ./back:/var/www/html:cached
```

### Multi-Stage Builds

Optimize image sizes with multi-stage builds (already implemented in Dockerfile.frontend).

### Docker Secrets

For sensitive data in production:

```bash
echo "my_secret_password" | docker secret create mongo_root_password -
```

```yaml
services:
  mongodb:
    secrets:
      - mongo_root_password
    environment:
      MONGO_INITDB_ROOT_PASSWORD_FILE: /run/secrets/mongo_root_password

secrets:
  mongo_root_password:
    external: true
```

### CI/CD Integration

**GitHub Actions example:**
```yaml
name: Build and Deploy

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build images
        run: bash docker-build.sh
      - name: Push to registry
        run: |
          docker tag grc-back:latest registry.example.com/grc-back:latest
          docker push registry.example.com/grc-back:latest
```

---

## Quick Reference

### Common Commands

```bash
# Build
bash docker-build.sh

# Start
bash docker-up.sh

# Stop
bash docker-down.sh

# Status
bash docker-status.sh

# Logs
bash docker-logs.sh

# Execute command
docker compose exec [service] [command]

# Restart
docker compose restart [service]

# Remove everything
bash docker-down.sh --volumes --images
```

### Service URLs

- Frontend: http://localhost
- API Gateway: http://localhost:8000 (production)
- Back: http://localhost:9090
- Notification: http://localhost:6060
- User: http://localhost:7070
- Regulator: http://localhost:3030
- Strategic: http://localhost:8080
- KPIs: http://localhost:5050
- WebSocket: ws://localhost:9000

### File Locations

- Docker Compose: `docker-compose.yml`
- Environment: `.env`
- Dockerfiles: `docker/Dockerfile.*`
- Nginx configs: `docker/nginx-*.conf`
- MongoDB init: `docker/mongo-init.js`
- Scripts: `docker-*.sh`

---

## Support

For issues:
1. Check logs: `bash docker-logs.sh --service [name]`
2. Check status: `bash docker-status.sh`
3. Verify configuration: `cat .env`
4. Check Docker: `docker info`

**Related Documentation:**
- [Installation Guide](INSTALLATION.md)
- [Quick Start](QUICK-START.md)
- [Assessment Features](ASSESSMENT_RISK_TRACKING_README.md)

---

**Version**: 1.0.0
**Last Updated**: 2025-12-16
**Platform**: GRC Microservices on Docker
