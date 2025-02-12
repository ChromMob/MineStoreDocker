#!/bin/bash

minestorePath="/var/www/minestore"

COLOR_YELLOW='\033[1;33m'
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_ORANGE='\033[38;5;208m'
COLOR_NC='\033[0m'
COLOR_BOLD='\033[1m'

output() {
    echo -e "* $1"
}

success() {
    echo ""
    output "${COLOR_GREEN}SUCCESS${COLOR_NC}: $1"
    echo ""
}

error() {
    echo ""
    echo -e "* ${COLOR_RED}ERROR${COLOR_NC}: $1" 1>&2
    echo ""
}

warning() {
    echo ""
    output "${COLOR_YELLOW}WARNING${COLOR_NC}: $1"
    echo ""
}

print_brake() {
    for ((n = 0; n < $1; n++)); do
        echo -n "#"
    done
    echo ""
}

array_contains_element() {
    local e match="$1"
    shift
    for e; do [[ "$e" == "$match" ]] && return 0; done
    return 1
}

hyperlink() {
    echo -e "\e]8;;${1}\a${1}\e]8;;\a"
}

# First argument list of packages to install, second argument for quite mode
install_packages() {
    local args=""
    if [[ $2 == true ]]; then
        case "$OS" in
        ubuntu | debian) args="-qq" ;;
        *) args="-q" ;;
        esac
    fi

    # Eval needed for proper expansion of arguments
    case "$OS" in
    ubuntu | debian)
        eval apt-get -y $args install "$1"
        ;;
    esac
}

apt update -y

cat >/etc/nginx/conf.d/default.conf <<EOF
geo \$limit {
   default 1;
   127.0.0.1 0;
   ::1 0;
}

limit_req_zone \$binary_remote_addr zone=one:40m rate=180r/m;
limit_req zone=one burst=86 nodelay;
limit_req_log_level warn;
limit_req_status 429;

server {
  resolver 8.8.8.8 valid=300s;
  root $minestorePath/public;
  index index.php;
  server_name $minestoreDomain;
  client_max_body_size 64m;

  proxy_http_version 1.1;
  proxy_set_header Upgrade \$http_upgrade;
  proxy_set_header Connection 'upgrade';
  proxy_set_header Host \$host;
  proxy_cache_bypass \$http_upgrade;

  location /_next/static {
    #proxy_cache STATIC;
    proxy_pass http://frontend:3000;
  }

  location /static {
    #proxy_cache STATIC;
    proxy_ignore_headers Cache-Control;
    proxy_cache_valid 60m;
    proxy_pass http://frontend:3000;
  }

  location / {
    if (\$limit = 0) {
        set \$limit_req_zone "";
    }
    proxy_pass http://frontend:3000;
  }

  location ~ ^/(admin|api|install|initiateInstallation) {
    if (\$limit = 0) {
        set \$limit_req_zone "";
    }
    proxy_pass http://127.0.0.1:8090;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
  }

  location ~ ^/(assets|css|flags|fonts|img|js|libs|res|scss|style)/ {
    proxy_pass http://127.0.0.1:8090;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
  }
}

server {
  listen 8090;
  listen [::]:8090;

  root $minestorePath/public;
  index index.php;
  server_name $minestoreDomain;
  client_max_body_size 64m;

  location / {
    try_files \$uri \$uri/ /index.php?\$query_string;
  }
  
  location ~ \.php$ {
    if (\$limit = 0) {
        set \$limit_req_zone "";
    }
    try_files \$uri =404;
    fastcgi_split_path_info ^(.+\.php)(.*)$;
    fastcgi_pass backend:9000;
    fastcgi_index index.php;
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    include fastcgi_params;
  }
}
EOF

nginx -g "daemon off;"
