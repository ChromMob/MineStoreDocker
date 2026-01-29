# syntax=docker/dockerfile:1
FROM php:8.3-fpm-bookworm

# Copy and run initial installation
COPY install.sh /install.sh
RUN chmod +x /install.sh
RUN /install.sh

# Install supervisor before PHP extensions
RUN apt-get update && apt-get install -y \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
RUN chmod +x /usr/local/bin/install-php-extensions
RUN install-php-extensions @composer zip mysqli pdo_mysql gd

# Configure PHP
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Copy supervisor configuration
COPY supervisord.conf /etc/supervisor/supervisord.conf

# Create log directories for supervisor programs
RUN mkdir -p /var/www/minestore/storage/logs && \
    chown -R www-data:www-data /var/www/minestore/storage

# Copy initialization script
COPY init.sh /init.sh
RUN chmod +x /init.sh

# Run init script, then start supervisord
CMD ["/bin/bash", "-c", "/init.sh && exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf"]