# syntax=docker/dockerfile:1
FROM php:8.3-fpm-bookworm

COPY install.sh /install.sh
RUN chmod +x /install.sh
RUN /install.sh

ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
RUN chmod +x /usr/local/bin/install-php-extensions
RUN install-php-extensions @composer zip mysqli pdo_mysql gd

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

COPY init.sh /init.sh
RUN chmod +x /init.sh

CMD ["/init.sh"]
