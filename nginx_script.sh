#!/bin/bash

DOMAIN_CONF_FILE="./domains.conf"
NGINX_CONF_DIR="./docker/nginx/conf.d"
HTTP_TEMPLATE_FILE="./templates/http.template"
HTTPS_TEMPLATE_FILE="./templates/https.template"
DOCKERFILE="./docker-compose.yml"

mkdir -p $NGINX_CONF_DIR

if [ ! -f "$DOMAIN_CONF_FILE" ]; then
    echo "Domenlar va portlar ro'yxati fayli ($DOMAIN_CONF_FILE) topilmadi."
    exit 1
fi

generate_config() {
    local template_file=$1
    local domain=$2
    local http_port=$3
    local conf_file=$4

    sed -e "s/{{DOMAIN}}/$domain/g" -e "s/{{HTTP_PORT}}/$http_port/g" $template_file > $conf_file
    echo "$domain uchun konfiguratsiya yaratildi: $conf_file"
}

while read -r DOMAIN HTTP_PORT HTTPS_PORT; do
    [[ "$DOMAIN" =~ ^#.*$ || -z "$DOMAIN" ]] && continue

    CONF_FILE="$NGINX_CONF_DIR/$DOMAIN.conf"

    if [[ "$HTTPS_PORT" == "~" ]]; then

        generate_config "$HTTP_TEMPLATE_FILE" "$DOMAIN" "$HTTP_PORT" "$CONF_FILE"
    else

        generate_config "$HTTPS_TEMPLATE_FILE" "$DOMAIN" "$HTTP_PORT" "$CONF_FILE"

        echo "Certbot orqali $DOMAIN uchun SSL sertifikatini olish..."
        CERTBOT_OUTPUT=$(docker-compose run --rm certbot certonly --webroot --webroot-path=/var/www/certbot -d $DOMAIN 2>&1)

        echo "Certbot javobi $DOMAIN uchun:"
        echo "$CERTBOT_OUTPUT"

        if [[ "$CERTBOT_OUTPUT" == *"error"* || "$CERTBOT_OUTPUT" == *"failed"* ]]; then
            echo "$DOMAIN uchun SSL sertifikatini olishda xatolik yuz berdi!"
            exit 1
        else
            echo "$DOMAIN uchun SSL sertifikati muvaffaqiyatli olindi!"
        fi
    fi

done < "$DOMAIN_CONF_FILE"

echo "Nginx xizmatini qayta ishga tushirish..."

docker compose -f $DOCKERFILE down
docker compose -f $DOCKERFILE up -d

echo "Barcha jarayonlar muvaffaqiyatli yakunlandi!"
