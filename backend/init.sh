#!/bin/bash

minestorePath="/var/www/minestore"

cd $minestorePath
export COMPOSER_ALLOW_SUPERUSER=1

init_server() {
    clear
    cd $minestorePath
    export COMPOSER_ALLOW_SUPERUSER=1
    php /usr/local/bin/composer install --no-interaction --prefer-dist --optimize-autoloader
    php $minestorePath/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3 & php $minestorePath/artisan cron:worker & php $minestorePath/artisan queue:listen & php $minestorePath/artisan schedule:run >> /dev/null 2>&1 & php artisan discord:run & php $minestorePath/artisan queue:work --queue=paynow --sleep=3 --tries=3 & php-fpm
    exit 1
}


#if /var/www/minestore already exists and /var/www/minestore/.env has INSTALLED = 1
if [ -d "/var/www/minestore" ] && [ -f "/var/www/minestore/.env" ] && [ "$(cat /var/www/minestore/.env | grep INSTALLED=1)" ]; then
    EXTENSION_DIR=$(php-config --extension-dir)
    INI_DIR="/usr/local/etc/php/conf.d"
    if [ -f "timezone.ini" ]; then
        echo "Setting up timezone.ini..."
        cp "timezone.ini" "${INI_DIR}/timezone.ini"
    fi

    if [ -f "timezone.so" ]; then
        echo "Installing timezone.so..."
        cp "timezone.so" "${EXTENSION_DIR}/timezone.so"
    fi
    php /usr/local/bin/composer install
    init_server
    exit 0
fi

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

configure_server() {
    clear
    mkdir -p $minestorePath
    cd $minestorePath

    success "Procedure for License Activation"

    response=$(curl -s "https://minestorecms.com/api/verify/$licenseKey")

    if ! echo "$response" | grep -q "SUCCESS"; then
        error "The license key provided is inactive."
        exit 1
    fi

    echo "Downloading MineStoreCMS... from https://minestorecms.com/download/v3/$licenseKey"
    wget --no-check-certificate https://minestorecms.com/download/v3/$licenseKey -O ./minestorecms.tar.gz
    tar -xzf ./minestorecms.tar.gz .
    rm -f ./minestorecms.tar.gz

    success "Archive has been unzipped..."

    EXTENSION_DIR=$(php-config --extension-dir)
    INI_DIR="/usr/local/etc/php/conf.d"
    if [ -f "timezone.ini" ]; then
        echo "Setting up timezone.ini..."
        cp "timezone.ini" "${INI_DIR}/timezone.ini"
    fi

    if [ -f "timezone.so" ]; then
        echo "Installing timezone.so..."
        cp "timezone.so" "${EXTENSION_DIR}/timezone.so"
    fi
    success "Timezone extension has been installed."

    sed "s,^APP_URL=.*\$,APP_URL=https://$minestoreDomain," .env >.env.temp
    mv -f .env.temp .env
    rm -rf .env.temp
    success "Configured APP_URL."

    sed "s,^DB_HOST=.*\$,DB_HOST=mariadb," .env >.env.temp
    mv -f .env.temp .env
    rm -rf .env.temp
    success "Configured database host."

    sed "s,^DB_DATABASE=.*\$,DB_DATABASE=$MYSQL_DATABASE," .env >.env.temp
    mv -f .env.temp .env
    rm -rf .env.temp
    success "Configured database name."
    
    sed "s,^DB_USERNAME=.*\$,DB_USERNAME=$MYSQL_USER," .env >.env.temp
    mv -f .env.temp .env
    rm -rf .env.temp
    success "Configured database user."

    sed "s,^DB_PASSWORD=.*\$,DB_PASSWORD=$MYSQL_PASSWORD," .env >.env.temp
    mv -f .env.temp .env
    rm -rf .env.temp
    success "Configured database user password."

    sed "s,^TIMEZONE=.*\$,TIMEZONE=$timezone," .env >.env.temp
    mv -f .env.temp .env
    rm -rf .env.temp
    success "Configured timezone in the enviroment file."

    sed "s,^LICENSE_KEY=.*\$,LICENSE_KEY=$licenseKey," .env >.env.temp
    mv -f .env.temp .env
    rm -rf .env.temp
    success "Configured license key."

    sed "s,^NEXT_PUBLIC_API_URL=.*\$,NEXT_PUBLIC_API_URL=https://$minestoreDomain," ./frontend/.env >./frontend/.env.temp
    mv -f ./frontend/.env.temp ./frontend/.env
    rm -rf ./frontend/.env.temp
    success "Configured enviroment frontend config file."

    chown -R www-data:www-data .
    chmod -R 755 .env storage/* bootstrap/cache public/img public/img/*
    chown root updater
    chmod u=rwx,go=xr,+s updater
    chmod +x $minestorePath/frontend.sh
    success "Running frontend..."

    export COMPOSER_ALLOW_SUPERUSER=1
    php /usr/local/bin/composer install

    #sudo certbot --$webserverUse

    php artisan cache:clear
    php artisan config:clear
    php artisan optimize
    php artisan config:clear
    php artisan cache:clear
    php artisan optimize

    #source ~/.profile
    #export NVM_DIR="$HOME/.nvm"
    #[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
    #[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion

    #curl -fsSL https://get.pnpm.io/install.sh | sh -

    #export PNPM_HOME="/root/.local/share/pnpm"
    #case ":$PATH:" in
    #*":$PNPM_HOME:"*) ;;
    #*) export PATH="$PNPM_HOME:$PATH" ;;
    #esac

    #source /root/.bashrc

    #cd $minestorePath/frontend
    #pnpm install
    #pnpm exec next telemetry disable
    #pnpm install pm2 -g
}

configure_server
init_server
