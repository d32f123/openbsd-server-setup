#!/bin/sh

doas rcctl enable nginx

NGINX_LOGS=/var/log/nginx
NGINX_CONF=/etc/nginx
NGINX_WWW=/var/www
NGINX_USER=www
NGINX_GROUP=www

echo "${YELLOW}Setting up $NGINX_LOGS directory${NORM}"
doas mkdir $NGINX_LOGS
doas chown ${NGINX_USER}:${NGINX_GROUP} $NGINX_LOGS

echo "${YELLOW}Setting up $NGINX_CONF directory${NORM}"
doas mkdir $NGINX_CONF/{sites-available,sites-enabled}

doas cp nginx/{nginx.conf,secure,secure_only,www_redirect,certbot_enabler} $NGINX_CONF/
doas chown ${NGINX_USER}:${NGINX_GROUP} $NGINX_CONF/{nginx.conf,secure,secure_only,www_redirect,certbot_enabler}

echo "${YELLOW}Configuring NGINX for the following sites: $NGINX_DOMAINS${NORM}"
for site in $NGINX_DOMAINS; do
    doas mkdir $NGINX_WWW/$site
    doas chown ${NGINX_USER}:${NGINX_GROUP} $NGINX_WWW/$site

    sed -E "s/{{domain}}/${site}/g" nginx/site-templates/insecure.site | doas tee $NGINX_CONF/sites-available/${site}.insecure.site >/dev/null
    sed -E "s/{{domain}}/${site}/g" nginx/site-templates/secure.site | doas tee $NGINX_CONF/sites-available/${site}.secure.site >/dev/null

    doas ln -s -f $NGINX_CONF/{sites-available,sites-enabled}/${site}.insecure.site
done

echo "${YELLOW}Generating prompt for site $DOMAIN_NAME${NORM}"
SITE_PROMPT="<html><body>Hello there! Edit me at $NGINX_WWW/$DOMAIN_NAME/index.html</body></html>"
echo "$SITE_PROMPT" | doas tee $NGINX_WWW/$DOMAIN_NAME/index.html >/dev/null

echo "${YELLOW}Reloading nginx with sites' configurations${NORM}"
doas /etc/rc.d/nginx restart || {
    echo "${RED}Could not start nginx with the new configuration${NORM}"
    exit 1
}
