#!/bin/sh

NGINX_LOGS=/var/log/nginx
NGINX_CONF=/etc/nginx
NGINX_WWW=/var/www
NGINX_USER=www
NGINX_GROUP=www

if [ ! -f /etc/ssl/certs/dh.pem ] && [ -n "$DO_DH_PARAMS" ]
then
    echo "${YELLOW}Generating DH, please wait a few minutes${NORM}"
    doas mkdir -p /etc/ssl/certs
    cd /etc/ssl/certs
    doas openssl dhparam -out dh.pem 4096
    cd -
elif [ -z "$DO_DH_PARAMS" ]
then
    echo "${YELLOW}Disabling custom DH params${NORM}"
    doas sed -i.bak -E -e 's/(^ssl_dhparam .*$)/# \1/' $NGINX_CONF/secure
fi

if [ -n "$DO_HSTS_PRELOAD" ]
then
    echo "${YELLOW}Enabling HSTS Preloading${NORM}"
    doas sed -i.bak -e 's/includeSubDomains"/includeSubDomains; preload"/' $NGINX_CONF/secure
fi

echo "${YELLOW}Getting SSL certificates, switching to secure sites${NORM}"
for site in $NGINX_DOMAINS; do
    doas certbot certonly --webroot --agree-tos -m "$USER_NAME@$DOMAIN_NAME" -d "$site,www.$site" -w $NGINX_WWW/$site
    doas ln -s -f $NGINX_CONF/{sites-available,sites-enabled}/${site}.secure.site
    doas rm $NGINX_CONF/sites-enabled/${site}.insecure.site
done
doas /etc/rc.d/nginx reload || {
    echo "${RED}Failed to load nginx with the new configuration${NORM}"
    exit 1
}

echo "${YELLOW}Creating a cron job to update certificates weekly${NORM}"
CRONJOB="@monthly $(which certbot) renew --quiet --force-renewal --post-hook '/etc/rc.d/nginx reload'"
{ doas crontab -l 2>/dev/null ; echo "$CRONJOB" ; } | doas crontab -
