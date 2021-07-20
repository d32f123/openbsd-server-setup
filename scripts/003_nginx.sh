#!/bin/sh

doas rcctl enable nginx

NGINX_LOGS=/var/log/nginx
NGINX_CONF=/etc/nginx
NGINX_WWW=/var/www
NGINX_USER=www
NGINX_GROUP=www

echo "Setting up $NGINX_LOGS directory"
doas mkdir $NGINX_LOGS
doas chown ${NGINX_USER}:${NGINX_GROUP} $NGINX_LOGS

echo "Setting up $NGINX_CONF directory"
doas mkdir $NGINX_CONF/{sites-available,sites-enabled}

sites="${DOMAIN_NAME} mail.${DOMAIN_NAME}"
echo "Creating nginx configurations for the following sites: $sites"
for site in $sites; do
    doas mkdir $NGINX_WWW/$site
    doas chown ${NGINX_USER}:${NGINX_GROUP} $NGINX_WWW/$site

    sed -E "s/{{domain}}/${site}/gp" nginx/site-templates/insecure.site | doas tee $NGINX_CONF/sites-available/${site}.insecure.site
    sed -E "s/{{domain}}/${site}/gp" nginx/site-templates/secure.site | doas tee $NGINX_CONF/sites-available/${site}.secure.site

    doas ln -s $NGINX_CONF/{sites-available,sites-enabled}/${site}.insecure.site
done

echo "Generating prompt for site $DOMAIN_NAME"
SITE_PROMPT="<html><body>Hello there! Edit me at $NGINX_WWW/$DOMAIN_NAME/index.html</body></html>"
echo "$SITE_PROMPT" | doas tee $NGINX_WWW/$DOMAIN_NAME/index.html

echo "Reloading nginx with sites' configurations"
doas /etc/rc.d/nginx restart

echo "Generating DH"
doas mkdir /etc/ssl/certs
pushd /etc/ssl/certs
doas openssl dhparam -out dh.pem 4096
popd

echo "Getting SSL certificates, switching to secure sites"
for site in $sites; do
    doas certbot certonly --webroot --agree-tos -m "$USER_NAME@$DOMAIN_NAME" -d "$site" -w $NGINX_WWW/$site
    doas ln -s -f $NGINX_CONF/{sites-available,sites-enabled}/${site}.secure.site
    doas rm $NGINX_CONF/sites-enabled/${site}.insecure.site
done
doas /etc/rc.d/nginx reload

echo "Creating a cron job to update certificates weekly"
CRONJOB="@weekly $(which certbot) renew --quiet --force-renewal --post-hook '/etc/rc.d/nginx reload'"
{ doas crontab -l 2>/dev/null ; echo "$CRONJOB" } | doas crontab -
