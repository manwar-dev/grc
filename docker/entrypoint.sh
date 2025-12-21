#!/bin/sh
set -e
cd /var/www/html
if [ ! -d vendor ]; then
    composer install --no-dev --optimize-autoloader --no-interaction
fi
php artisan key:generate || true
php artisan jwt:secret --force || true
exec "$@"
