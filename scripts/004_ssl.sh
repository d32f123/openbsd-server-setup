#!/bin/sh

NGINX_LOGS=/var/log/nginx
NGINX_CONF=/etc/nginx
NGINX_WWW=/var/www
NGINX_USER=www
NGINX_GROUP=www

if [ ! -f /etc/ssl/certs/dh.pem ]
then
    echo "Generating DH"
    doas mkdir -p /etc/ssl/certs
    cd /etc/ssl/certs
    doas openssl dhparam -out dh.pem 4096
    cd -
fi

echo "Getting SSL certificates, switching to secure sites"
for site in $NGINX_DOMAINS; do
    doas certbot certonly --webroot --agree-tos -m "$USER_NAME@$DOMAIN_NAME" -d "$site,www.$site" -w $NGINX_WWW/$site
    doas ln -s -f $NGINX_CONF/{sites-available,sites-enabled}/${site}.secure.site
    doas rm $NGINX_CONF/sites-enabled/${site}.insecure.site
done
doas /etc/rc.d/nginx reload

echo "Creating a cron job to update certificates weekly"
CRONJOB="@weekly $(which certbot) renew --quiet --force-renewal --post-hook '/etc/rc.d/nginx reload'"
{ doas crontab -l 2>/dev/null ; echo "$CRONJOB" ; } | doas crontab -
