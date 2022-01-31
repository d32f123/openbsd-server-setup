#!/bin/sh

ENVS="$(dirname $0)/../env.d"
. "$ENVS/general.sh"

echo "${YELLOW}Downloading dependencies${NORM}"
doas pkg_add nginx || panic "Failed to download dependencies"

doas rcctl enable nginx

. "$ENVS/nginx.sh"

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

echo "${YELLOW}Generating index.html for site $DOMAIN_NAME${NORM}"
sed -e "s/{{title}}/$DOMAIN_NAME/;
        s?{{stub}}?Hello there! Edit me at $NGINX_WWW/$DOMAIN_NAME/index.html?;
" nginx/site-templates/index.html | doas tee $NGINX_WWW/$DOMAIN_NAME/index.html >/dev/null

echo "${YELLOW}Reloading nginx with sites' configurations${NORM}"
doas rcctl restart nginx || panic "Could not start nginx with the new configuration"

echo "${PURPLE}${BOLD}Nginx configuration is available at $NGINX_CONF
Websites serve roots are available at $NGINX_WWW
Use \`doas rcctl reload nginx\` to reload nginx${NORM}" | postinstall