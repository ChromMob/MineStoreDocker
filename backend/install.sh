#!/bin/bash

minestorePath="/var/www/minestore"
phpVersion="8.2"
customMysql=0
timezone=""


export OS=""
export OS_VER_MAJOR=""
export CPU_ARCHITECTURE=""
export ARCH=""
export SUPPORTED=false

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


make_swap() {
    SWAP_SIZE="2G"
    SWAP_PATH="/swapfile"
    TOTAL_MEMORY_MB=$(get_total_memory_mb)

    # Check if total memory is less than 2048 MB (2 GB)
    if [ "$TOTAL_MEMORY_MB" -lt 2048 ]; then
        echo "Total RAM is less than 2GB. Proceeding with swap file creation."
        echo "Creating a swap file of size $SWAP_SIZE at $SWAP_PATH"

        sudo fallocate -l $SWAP_SIZE $SWAP_PATH
        sudo chmod 600 $SWAP_PATH
        sudo mkswap $SWAP_PATH
        sudo swapon $SWAP_PATH
        echo "$SWAP_PATH none swap sw 0 0" | sudo tee -a /etc/fstab
        echo
        echo "Done! You now have a $SWAP_SIZE swap file at $SWAP_PATH"
    else
        echo "Total RAM is 2GB or more. No swap file needed."
    fi
}

install_basic() {
    apt update -y
    install_packages "curl sudo openssl zip unzip build-essential cron tzdata netcat-traditional wget"
}

configure_php() {
    if grep -q '^post_max_size ' "$PHP_INI_DIR/php.ini"; then
        sed 's,^post_max_size =.*$,post_max_size = 64M,' "$PHP_INI_DIR/php.ini" >temp_php.ini
        mv -f temp_php.ini "$PHP_INI_DIR/php.ini"
    else
        sed '/^\[PHP\].*/a post_max_size = 64M' "$PHP_INI_DIR/php.ini" >temp_php.ini
        mv -f temp_php.ini "$PHP_INI_DIR/php.ini"
    fi

    if grep -q '^memory_limit ' "$PHP_INI_DIR/php.ini"; then
        sed 's,^memory_limit =.*$,memory_limit = 256M,' "$PHP_INI_DIR/php.ini" >temp_php.ini
        mv -f temp_php.ini "$PHP_INI_DIR/php.ini"
    else
        sed '/^\[PHP\].*/a memory_limit = 256M' "$PHP_INI_DIR/php.ini" >temp_php.ini
        mv -f temp_php.ini "$PHP_INI_DIR/php.ini"
    fi

    if grep -q '^upload_max_filesize ' "$PHP_INI_DIR/php.ini"; then
        sed 's,^upload_max_filesize =.*$,upload_max_filesize = 64M,' "$PHP_INI_DIR/php.ini" >temp_php.ini
        mv -f temp_php.ini "$PHP_INI_DIR/php.ini"
    else
        sed '/^\[PHP\].*/a upload_max_filesize = 64M' "$PHP_INI_DIR/php.ini" >temp_php.ini
        mv -f temp_php.ini "$PHP_INI_DIR/php.ini"
    fi

    rm -f temp_php.ini
}

install_service() {
    # Queue Service
    cat >/etc/systemd/system/minestore_queue.service <<EOF
[Unit]
Description=MineStoreCMS Queue Worker
After=network.target
After=nginx.service
Wants=nginx.service
After=mysql.service
Wants=mysql.service
After=php$phpVersion-fpm.service
Wants=php$phpVersion-fpm.service

[Service]
Type=simple
User=www-data
Group=www-data
Restart=always
WorkingDirectory=$minestorePath
ExecStart=/usr/bin/php$phpVersion $minestorePath/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
OOMScoreAdjust=-100
StandardOutput=append:/var/log/minestore_queue.log
StandardError=append:/var/log/minestore_queue-error.log

[Install]
WantedBy=multi-user.target
EOF

    # Worker Service
    cat >/etc/systemd/system/minestore_worker.service <<EOF
[Unit]
Description=MineStoreCMS Cron Worker
After=network.target
After=nginx.service
Wants=nginx.service
After=mysql.service
Wants=mysql.service
After=php$phpVersion-fpm.service
Wants=php$phpVersion-fpm.service

[Service]
Type=simple
User=www-data
Group=www-data
Restart=always
WorkingDirectory=$minestorePath
ExecStart=/usr/bin/php$phpVersion $minestorePath/artisan cron:worker
OOMScoreAdjust=-100
StandardOutput=append:/var/log/minestore_worker.log
StandardError=append:/var/log/minestore_worker-error.log

[Install]
WantedBy=multi-user.target
EOF

    # Schedule Service
    cat >/etc/systemd/system/minestore_schedule.service <<EOF
[Unit]
Description=MineStoreCMS Schedule
After=network.target
After=nginx.service
Wants=nginx.service
After=mysql.service
Wants=mysql.service
After=php$phpVersion-fpm.service
Wants=php$phpVersion-fpm.service

[Service]
Type=simple
User=www-data
Group=www-data
Restart=always
WorkingDirectory=$minestorePath
ExecStart=/usr/bin/php$phpVersion $minestorePath/artisan schedule:run >> /dev/null 2>&1
OOMScoreAdjust=-100
StandardOutput=append:/var/log/minestore_schedule.log
StandardError=append:/var/log/minestore_schedule-error.log

[Install]
WantedBy=multi-user.target
EOF

    # Discord Service
    cat >/etc/systemd/system/minestore_discord.service <<EOF
[Unit]
Description=MineStoreCMS Discord Bot
After=network.target
After=nginx.service
Wants=nginx.service
After=mysql.service
Wants=mysql.service
After=php$phpVersion-fpm.service
Wants=php$phpVersion-fpm.service

[Service]
Type=simple
User=www-data
Group=www-data
Restart=always
RestartSec=5
WorkingDirectory=$minestorePath
ExecStart=/usr/bin/php$phpVersion artisan discord:run
OOMScoreAdjust=-100
StandardOutput=append:/var/log/minestore_discord.log
StandardError=append:/var/log/minestore_discord-error.log

[Install]
WantedBy=multi-user.target
EOF

    # Frontend Service
    sudo iptables -A INPUT -p tcp --dport 25401 -j DROP
    cat >/etc/systemd/system/minestore_frontend.service <<EOF
[Unit]
Description=MineStoreCMS Frontend
After=network.target
After=nginx.service
Wants=nginx.service
After=mysql.service
Wants=mysql.service
After=php$phpVersion-fpm.service
Wants=php$phpVersion-fpm.service

[Service]
Type=simple
User=root
Restart=always
PIDFile=/var/run/minestore_frontend.pid
WorkingDirectory=$minestorePath
ExecStart=/usr/bin/sudo /bin/bash $minestorePath/frontend.sh
OOMScoreAdjust=-100
StandardOutput=append:/var/log/minestore_frontend.log
StandardError=append:/var/log/minestore_frontend-error.log

[Install]
WantedBy=multi-user.target
EOF

    # Setup log rotation for all services
    cat >/etc/logrotate.d/minestore_services <<EOF
/var/log/minestore_queue.log /var/log/minestore_queue-error.log
/var/log/minestore_worker.log /var/log/minestore_worker-error.log
/var/log/minestore_schedule.log /var/log/minestore_schedule-error.log
/var/log/minestore_discord.log /var/log/minestore_discord-error.log
/var/log/minestore_frontend.log /var/log/minestore_frontend-error.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 www-data www-data
    postrotate
        systemctl restart minestore_queue.service
        systemctl restart minestore_worker.service
        systemctl restart minestore_schedule.service
        systemctl restart minestore_discord.service
        systemctl restart minestore_frontend.service
    endscript
}
EOF

    # Setup permissions only for discord service
    echo "www-data ALL=(ALL) NOPASSWD: /bin/systemctl start minestore_discord.service, /bin/systemctl stop minestore_discord.service, /bin/systemctl restart minestore_discord.service" | sudo tee -a /etc/sudoers.d/minestore_discord

    # Reload and enable all services
    systemctl daemon-reload
    systemctl enable minestore_queue.service
    systemctl enable minestore_worker.service
    systemctl enable minestore_schedule.service
    systemctl enable minestore_discord.service
    systemctl enable minestore_frontend.service
}

configure_final() {
    systemctl start minestore_queue
    systemctl start minestore_worker
    systemctl start minestore_schedule
    systemctl start minestore_frontend
    #sleep 5s
    #echo "restart" | nc -N localhost 25401

    crontab -l | {
        cat
        echo "0 5 * * * /usr/bin/certbot renew --quiet"
    } | crontab -
    clear
    echo
    success "Installation completed successfully!"
    success "Visit your website to install MineStoreCMS: ${COLOR_ORANGE}${minestoreDomain}/install${COLOR_NC}"
    echo -e "${COLOR_BOLD}Please ${COLOR_ORANGE}restart your VPS${COLOR_NC}${COLOR_BOLD} server before proceeding with the installation.${COLOR_NC}"
}

welcome() {
    clear
    # Define the color code for orange
    ORANGE='\033[38;5;208m'
    # Define the color reset code
    NC='\033[0m' # No Color

    echo -e "${ORANGE} __  __ _             _____ _                  _____ __  __  _____${NC}"
    echo -e "${ORANGE}|  \\/  (_)           / ____| |                / ____|  \\/  |/ ____|${NC}"
    echo -e "${ORANGE}| \\  / |_ _ __   ___| (___ | |_ ___  _ __ ___| |    | \\  / | (___  ${NC}"
    echo -e "${ORANGE}| |\\/| | | '_ \\ / _ \\\\___ \\| __/ _ \\| '__/ _ \\ |    | |\\/| |\\___ \\ ${NC}"
    echo -e "${ORANGE}| |  | | | | | |  __/____) | || (_) | | |  __/ |____| |  | |____) |${NC}"
    echo -e "${ORANGE}|_|  |_|_|_| |_|\\___|_____/ \\__\\___/|_|  \\___|\\_____|_|  |_|_____/ ${NC}"
    echo ""
    echo ""

    output "MineStoreCMS PRO Installation"
    output ""
    output "Running $OS version $OS_VER."

    print_brake 70
}

# Detect OS
if [ -f /etc/os-release ]; then
    # freedesktop.org and systemd
    . /etc/os-release
    OS=$(echo "$ID" | awk '{print tolower($0)}')
    OS_VER=$VERSION_ID
elif type lsb_release >/dev/null 2>&1; then
    # linuxbase.org
    OS=$(lsb_release -si | awk '{print tolower($0)}')
    OS_VER=$(lsb_release -sr)
elif [ -f /etc/lsb-release ]; then
    # For some versions of Debian/Ubuntu without lsb_release command
    . /etc/lsb-release
    OS=$(echo "$DISTRIB_ID" | awk '{print tolower($0)}')
    OS_VER=$DISTRIB_RELEASE
elif [ -f /etc/debian_version ]; then
    # Older Debian/Ubuntu/etc.
    OS="debian"
    OS_VER=$(cat /etc/debian_version)
elif [ -f /etc/SuSe-release ]; then
    # Older SuSE/etc.
    OS="SuSE"
    OS_VER="?"
elif [ -f /etc/redhat-release ]; then
    # Older Red Hat, CentOS, etc.
    OS="Red Hat/CentOS"
    OS_VER="?"
else
    # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
    OS=$(uname -s)
    OS_VER=$(uname -r)
fi

OS=$(echo "$OS" | awk '{print tolower($0)}')
OS_VER_MAJOR=$(echo "$OS_VER" | cut -d. -f1)
CPU_ARCHITECTURE=$(uname -m)

case "$CPU_ARCHITECTURE" in
x86_64)
    ARCH=amd64
    ;;
arm64 | aarch64)
    ARCH=arm64
    ;;
*)
    error "Only x86_64 and arm64 are supported!"
    exit 1
    ;;
esac

case "$OS" in
ubuntu)
    [ "$OS_VER_MAJOR" == "20" ] && SUPPORTED=true
    [ "$OS_VER_MAJOR" == "22" ] && SUPPORTED=true
    [ "$OS_VER_MAJOR" == "23" ] && SUPPORTED=true
    [ "$OS_VER_MAJOR" == "24" ] && SUPPORTED=true
    export DEBIAN_FRONTEND=noninteractive
    ;;
debian)
    [ "$OS_VER_MAJOR" == "10" ] && SUPPORTED=true
    [ "$OS_VER_MAJOR" == "11" ] && SUPPORTED=true
    [ "$OS_VER_MAJOR" == "12" ] && SUPPORTED=true
    export DEBIAN_FRONTEND=noninteractive
    ;;
*)
    SUPPORTED=false
    ;;
esac

# exit if not supported
if [ "$SUPPORTED" == false ]; then
    output "$OS $OS_VER is not supported"
    error "Unsupported OS"
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    error "Please execute the command as the root user."
    exit 1
fi

welcome

install_basic
configure_php
make_swap
#install_service
#configure_final
exit 0
