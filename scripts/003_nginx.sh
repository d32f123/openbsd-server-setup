#!/bin/sh

doas rcctl enable nginx

NGINX_LOGS=/var/log/nginx
NGINX_CONF=/etc/nginx
NGINX_WWW=/var/www
NGINX_USER=www
NGINX_GROUP=www

doas mkdir $NGINX_LOGS
doas chown ${NGINX_USER}:${NGINX_GROUP} $NGINX_LOGS

doas mkdir $NGINX_CONF/{sites-available,sites-enabled}
sites="${DOMAIN_NAME} mail.${DOMAIN_NAME}"

# Create a http nginx website for each site
for site in $sites; do
    doas mkdir $NGINX_WWW/$site
    doas chown ${NGINX_USER}:${NGINX_GROUP} $NGINX_WWW/$site

    doas sed -E "s/{{domain}}/${site}/p" nginx/insecure.site >$NGINX_CONF/sites-available/${site}.insecure.site
    doas sed -E "s/{{domain}}/${site}/p" nginx/secure/site >$NGINX_CONF/sites-available/${site}.secure.site

    doas ln -s $NGINX_CONF/{sites-available,sites-enabled}/${site}.insecure.site
done
doas /etc/rc.d/nginx start
doas certbot certonly --webroot

for site in $sites; do
    doas ln -s -f $NGINX_CONF/{sites-available,sites-enabled}/${site}.secure.site
    doas rm $NGINX_CONF/sites-enabled/${site}.insecure.site
done
doas /etc/rc.d/nginx reload


# TODO: Link nginx files to /etc/nginx dir
# TODO: Prepare site configuration for BEFORE SSL and AFTER SSL