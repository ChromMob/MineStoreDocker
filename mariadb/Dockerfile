# syntax=docker/dockerfile:1
FROM mariadb:10.11

COPY my.cnf /etc/mysql/conf.d/
COPY init.sh /docker-entrypoint-initdb.d/
