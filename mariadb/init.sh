#!/bin/bash

 cat >/etc/mysql/conf.d/timezone.cnf <<EOF
[mysqld]
default_time_zone = '$timezone'
EOF
