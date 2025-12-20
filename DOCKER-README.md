# GRC Microservices - Docker Quick Reference

Ready-to-use Docker deployment for the GRC platform.

## Quick Start (3 Steps)

```bash
# 1. Build images (10-15 minutes)
bash docker-build.sh

# 2. Start services
bash docker-up.sh

# 3. Verify
bash docker-status.sh
```

Access: **http://localhost**

---

## Using Makefile (Recommended)

```bash
# Show all commands
make help

# Build and start
make build
make up

# Check status
make status

# View logs
make logs

# Stop services
make down
```

---

## File Structure

```
grc/
├── docker-compose.yml          # Main orchestration file
├── .env.docker                 # Environment template
├── .dockerignore              # Build optimization
├── Makefile                   # Convenient commands
│
├── Dockerfile.frontend        # Vue.js frontend
├── Dockerfile.laravel         # Base Laravel image
│
├── docker/
│   ├── Dockerfile.back        # Back service
│   ├── Dockerfile.notification # Notification service
│   ├── Dockerfile.user        # User service
│   ├── Dockerfile.regulator   # Regulator service
│   ├── Dockerfile.strategic   # Strategic plan service
│   ├── Dockerfile.kpis        # KPIs service
│   ├── mongo-init.js          # MongoDB initialization
│   ├── nginx-frontend.conf    # Frontend nginx config
│   └── nginx-gateway.conf     # API gateway config
│
└── Scripts:
    ├── docker-build.sh        # Build images
    ├── docker-up.sh           # Start services
    ├── docker-down.sh         # Stop services
    ├── docker-status.sh       # Check status
    └── docker-logs.sh         # View logs
```

---

## Service Ports

| Service | Port | URL |
|---------|------|-----|
| Frontend | 80 | http://localhost |
| Backend | 9090 | http://localhost:9090 |
| User Service | 7070 | http://localhost:7070 |
| Notification | 6060 | http://localhost:6060 |
| Regulator | 3030 | http://localhost:3030 |
| Strategic | 8080 | http://localhost:8080 |
| KPIs | 5050 | http://localhost:5050 |
| WebSocket | 9000 | ws://localhost:9000 |
| API Gateway* | 8000 | http://localhost:8000 |
| MongoDB | 27017 | localhost:27017 |
| Redis | 6379 | localhost:6379 |

*Production only

---

## Common Commands

### Using Scripts

```bash
# Build
bash docker-build.sh                    # Build all
bash docker-build.sh --service back     # Build one service
bash docker-build.sh --no-cache         # Force rebuild

# Start/Stop
bash docker-up.sh                       # Start all
bash docker-up.sh --production          # With API gateway
bash docker-down.sh                     # Stop all
bash docker-down.sh --volumes           # Stop and delete data

# Monitor
bash docker-status.sh                   # Service status
bash docker-logs.sh                     # All logs
bash docker-logs.sh --service back      # One service
```

### Using Makefile

```bash
# Build
make build                              # Build all
make build-service SERVICE=back         # Build one
make build-no-cache                     # Force rebuild

# Start/Stop
make up                                 # Start all
make up-prod                            # Production mode
make down                               # Stop all

# Monitor
make status                             # Service status
make logs                               # All logs
make logs-service SERVICE=back          # One service
make health                             # Health check

# Utilities
make exec SERVICE=back                  # Access container
make shell-mongodb                      # MongoDB shell
make shell-redis                        # Redis CLI
make artisan SERVICE=back CMD="migrate" # Run artisan
make cache-clear SERVICE=back           # Clear cache
make optimize SERVICE=back              # Optimize Laravel

# Maintenance
make backup-mongodb                     # Backup database
make clean                              # Clean Docker
make restart                            # Restart all
make restart-service SERVICE=back       # Restart one
```

### Using Docker Compose

```bash
# Start/Stop
docker compose up -d                    # Start all
docker compose down                     # Stop all
docker compose restart back             # Restart service

# Monitor
docker compose ps                       # List containers
docker compose logs -f back             # Follow logs
docker compose top back                 # Process list

# Execute
docker compose exec back bash           # Access shell
docker compose exec back php artisan tinker
docker compose exec mongodb mongosh
```

---

## Environment Configuration

Create `.env` from template:

```bash
cp .env.docker .env
```

Key settings:

```env
# MongoDB
MONGO_ROOT_USER=admin
MONGO_ROOT_PASSWORD=admin123

# Application
APP_ENV=production
APP_DEBUG=false

# Service URLs
VITE_API_BASE_URL=http://localhost:8000
VITE_WS_URL=ws://localhost:9000
```

---

## Troubleshooting

### Services won't start

```bash
# Check logs
make logs-service SERVICE=back

# Restart service
make restart-service SERVICE=back

# Rebuild
make down
make build
make up
```

### Port already in use

```bash
# Find process
sudo lsof -i :9090

# Kill process
sudo fuser -k 9090/tcp

# Or change port in docker-compose.yml
```

### Out of disk space

```bash
# Check usage
docker system df

# Clean up
make clean              # Safe cleanup
make clean-all          # Remove everything
```

### Permission issues

```bash
# Fix permissions
docker compose exec back chown -R www-data:www-data /var/www/html
docker compose exec back chmod -R 775 storage
```

### MongoDB connection

```bash
# Test connection
make shell-mongodb

# Check logs
make logs-service SERVICE=mongodb
```

### Service unhealthy

```bash
# Check health
make health

# View container details
docker inspect grc-back

# Restart
make restart-service SERVICE=back
```

---

## Production Deployment

### 1. Secure .env

```env
APP_ENV=production
APP_DEBUG=false
MONGO_ROOT_PASSWORD=strong_random_password
MONGO_APP_PASSWORD=another_strong_password
```

### 2. Start with production profile

```bash
make up-prod
# or
bash docker-up.sh --production
```

### 3. Configure firewall

```bash
# Allow HTTP/HTTPS only
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw deny 27017/tcp
```

### 4. Setup SSL

Use reverse proxy (Nginx, Traefik, Caddy) or:

```bash
docker compose exec nginx-gateway sh
apk add certbot certbot-nginx
certbot --nginx -d your-domain.com
```

### 5. Setup backups

```bash
# Manual backup
make backup-mongodb

# Automated (cron)
0 2 * * * cd /var/www/html/grc && make backup-mongodb
```

### 6. Monitor logs

```bash
# View logs
make logs

# Check stats
make stats

# Health check
make health
```

---

## Backup & Restore

### Backup MongoDB

```bash
make backup-mongodb
# Saves to: ./backups/mongodb-TIMESTAMP/
```

### Restore MongoDB

```bash
make restore-mongodb BACKUP=./backups/mongodb-20250116
```

### Manual backup

```bash
# Backup all databases
docker compose exec mongodb mongodump --out=/tmp/backup

# Copy from container
docker cp grc-mongodb:/tmp/backup ./my-backup
```

### Manual restore

```bash
# Copy to container
docker cp ./my-backup grc-mongodb:/tmp/restore

# Restore
docker compose exec mongodb mongorestore /tmp/restore
```

---

## Development Mode

For development with live code updates:

```bash
# Mount source code (edit docker-compose.yml)
volumes:
  - ./back:/var/www/html:cached

# Start
docker compose up -d

# Watch logs
docker compose logs -f back
```

---

## Architecture

```
Frontend (Vue.js) :80
         ↓
API Gateway :8000 (production)
         ↓
    ┌────┴────┬─────────┬──────────┐
    ↓         ↓         ↓          ↓
  Back   User Service  Notification Regulator
  :9090     :7070      :6060/:9000  :3030
    ↓         ↓         ↓          ↓
    └─────────┴─────────┴──────────┘
              ↓
         MongoDB :27017
         Redis :6379
```

---

## Included Services

**Backend (Laravel 11 + PHP 8.2):**
- back - Main GRC backend
- notification-service - Notifications + WebSocket
- user-service - User management
- regulator-service - Compliance
- strategic-plan-service - Planning
- kpis - KPI metrics

**Frontend:**
- Vue.js 3 SPA (production build)

**Infrastructure:**
- MongoDB 7.0
- Redis 7
- Nginx (frontend + gateway)

---

## Health Checks

All services include health checks:
- HTTP endpoint: `/api/health`
- Interval: 30s
- Timeout: 10s
- Retries: 3

Check health:
```bash
make health
```

---

## Resource Usage

View real-time stats:
```bash
make stats
docker stats
```

Typical usage:
- MongoDB: 500MB-1GB RAM
- Each service: 100-300MB RAM
- Redis: 50-100MB RAM
- Total: 2-4GB RAM

---

## Volumes

Persistent data stored in:
- `mongodb_data` - Database files
- `redis_data` - Cache
- `*_storage` - Service uploads/logs

List volumes:
```bash
make volumes
```

Remove volumes (⚠️ deletes data):
```bash
make down-volumes
```

---

## Next Steps

1. ✅ Build images: `make build`
2. ✅ Start services: `make up`
3. ✅ Check status: `make status`
4. ⚙️ Configure `.env` file
5. 🌐 Access http://localhost
6. 📚 Read [DOCKER-GUIDE.md](DOCKER-GUIDE.md) for details

---

## Documentation

- **DOCKER-GUIDE.md** - Complete Docker guide
- **INSTALLATION.md** - Traditional installation
- **QUICK-START.md** - Quick start guide
- **docker-compose.yml** - Service definitions

---

## Support

**Check logs:**
```bash
make logs-service SERVICE=back
```

**Restart service:**
```bash
make restart-service SERVICE=back
```

**Full restart:**
```bash
make rebuild
```

**Clean start:**
```bash
make down
make clean
make build
make up
```

---

**Ready to use Docker images for GRC Microservices Platform**
**Version**: 1.0.0 | **Last Updated**: 2025-12-16
