#!/bin/bash

# Sync local MongoDB to remote Docker MongoDB
# This script dumps the local MongoDB and restores it to the remote server

set -e

LOCAL_MONGO_HOST="127.0.0.1"
LOCAL_MONGO_PORT="27017"
LOCAL_MONGO_DB="grc"

REMOTE_HOST="84.8.122.158"
REMOTE_USER="ubuntu"
SSH_KEY="/root/oci.pem"

REMOTE_MONGO_HOST="srv-captain--cybermode-mongodb"
REMOTE_MONGO_PORT="27017"
REMOTE_MONGO_USER="admin"
REMOTE_MONGO_PASS="508a8bb33264c08425a3ee2d"
REMOTE_MONGO_DB="grc"

DUMP_DIR="/tmp/mongo-dump-$(date +%s)"

echo "=== MongoDB Sync Script ==="
echo "Local: ${LOCAL_MONGO_HOST}:${LOCAL_MONGO_PORT}/${LOCAL_MONGO_DB}"
echo "Remote: ${REMOTE_HOST} -> ${REMOTE_MONGO_HOST}/${REMOTE_MONGO_DB}"
echo

# Check if mongodump is available
if ! command -v mongodump &> /dev/null; then
    echo "Error: mongodump not found. Please install mongodb-database-tools"
    exit 1
fi

# Dump local MongoDB
echo "Dumping local MongoDB database..."
mongodump --host="${LOCAL_MONGO_HOST}" --port="${LOCAL_MONGO_PORT}" --db="${LOCAL_MONGO_DB}" --out="${DUMP_DIR}"

if [ ! -d "${DUMP_DIR}/${LOCAL_MONGO_DB}" ]; then
    echo "Error: Dump failed or database is empty"
    exit 1
fi

echo "Dump completed: ${DUMP_DIR}"

# Compress dump
echo "Compressing dump..."
tar -czf "${DUMP_DIR}.tar.gz" -C "${DUMP_DIR}" .

# Transfer to remote server
echo "Transferring dump to remote server..."
scp -i "${SSH_KEY}" "${DUMP_DIR}.tar.gz" "${REMOTE_USER}@${REMOTE_HOST}:/tmp/mongo-dump.tar.gz"

# Restore on remote server via Docker exec
echo "Restoring to remote MongoDB..."
ssh -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" << 'ENDSSH'
set -e

# Extract dump
mkdir -p /tmp/mongo-restore
tar -xzf /tmp/mongo-dump.tar.gz -C /tmp/mongo-restore

# Get MongoDB container ID
MONGO_CONTAINER=$(docker ps --filter "name=cybermode-mongodb" --format "{{.ID}}" | head -1)

if [ -z "$MONGO_CONTAINER" ]; then
    echo "Error: MongoDB container not found"
    exit 1
fi

echo "MongoDB container: $MONGO_CONTAINER"

# Copy dump into container
docker cp /tmp/mongo-restore "$MONGO_CONTAINER":/tmp/mongo-restore

# Restore database
echo "Running mongorestore in container..."
docker exec "$MONGO_CONTAINER" mongorestore \
    --host localhost \
    --port 27017 \
    --username admin \
    --password 508a8bb33264c08425a3ee2d \
    --authenticationDatabase admin \
    --db grc \
    --drop \
    /tmp/mongo-restore/grc

# Cleanup
docker exec "$MONGO_CONTAINER" rm -rf /tmp/mongo-restore
rm -rf /tmp/mongo-restore /tmp/mongo-dump.tar.gz

echo "Restore completed successfully!"
ENDSSH

# Cleanup local files
echo "Cleaning up local files..."
rm -rf "${DUMP_DIR}" "${DUMP_DIR}.tar.gz"

echo
echo "=== Sync completed successfully! ==="
