#!/bin/sh

cd /var/www/minestore/frontend
pnpm setup
pnpm install
pnpm exec next telemetry disable
pnpm install pm2 -g
pnpm run build
pnpm run start