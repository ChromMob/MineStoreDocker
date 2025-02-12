#!/bin/sh

while [ ! -d "/var/www/minestore" ] || [ ! -f "/var/www/minestore/.env" ] || [ -z "$(cat /var/www/minestore/.env | grep INSTALLED=1)" ]; do
    echo "Backend is not installed..."
    sleep 5; 
done


export PNPM_HOME="/var/www/minestore/frontend/.pnpm-store"

cd /var/www/minestore/frontend
pnpm install
pnpm exec next telemetry disable
pnpm install pm2 -g
pnpm run build
pnpm run start