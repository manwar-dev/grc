#!/bin/sh
set -e
cd /var/www/html
# Temporary fix: some services pin mongodb/mongodb ^2.0 in composer.json
# while the lock file still references 1.20. Align them before install.
if [ -f composer.json ] && grep -q '"mongodb/mongodb": "^2\.0"' composer.json; then
    sed -i 's/"mongodb\/mongodb": "\^2\.0"/"mongodb\/mongodb": "\^1.20"/' composer.json
fi
if [ ! -d vendor ]; then
    composer install --no-dev --optimize-autoloader --no-interaction
fi
php artisan key:generate || true
php artisan jwt:secret --force || true
exec "$@"
