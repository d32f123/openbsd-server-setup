#!/bin/sh

ENVS="$(dirname $0)/../env.d"
. "$ENVS/general.sh"

echo "${YELLOW}Downloading dependencies${NORM}"
doas pkg_add certbot || panic "Failed to download dependencies"

. "$ENVS/nginx.sh"

prompt_bool "Generate custom DH params for SSL? It will take about 10 minutes" "n" && {
   [ ! -f /etc/ssl/certs/dh.pem ] && {
    echo "${YELLOW}Generating DH, please wait a few minutes${NORM}"
    doas mkdir -p /etc/ssl/certs
    cd /etc/ssl/certs
    doas openssl dhparam -out dh.pem 4096
    cd -
   } || {
       echo "${YELLOW}DH already generated, to regenerate, remove /etc/ssl/certs/dh.pem${NORM}"
   }
} || {
    echo "${YELLOW}Disabling custom DH params${NORM}"
    doas sed -i.bak -E -e 's/(^ssl_dhparam .*$)/# \1/' $NGINX_CONF/secure
}

prompt_bool "Enable HSTS preload? Read more at https://hstspreload.org/" "n" && {
    echo "${YELLOW}Enabling HSTS Preloading${NORM}"
    doas sed -i.bak -e 's/includeSubDomains"/includeSubDomains; preload"/' $NGINX_CONF/secure
}

echo "${YELLOW}Getting SSL certificates, switching to secure sites${NORM}"
for site in $NGINX_DOMAINS; do
    doas certbot certonly --webroot --agree-tos -m "$USER_NAME@$DOMAIN_NAME" -d "$site,www.$site" -w "$NGINX_WWW/$site" $CERTBOT_FLAGS || {
        echo "${RED}Failed to get certificate for $site${NORM}"
        continue
    }
    success=yes
    doas ln -s -f $NGINX_CONF/{sites-available,sites-enabled}/${site}.secure.site
    doas rm $NGINX_CONF/sites-enabled/${site}.insecure.site
done
[ -n "$success" ] && doas /etc/rc.d/nginx reload || panic "Failed to load nginx with the new configuration"

echo "${YELLOW}Setting an entry to /etc/monthly.local to update certificates monthly${NORM}"
echo "@monthly $(which certbot) renew --quiet --force-renewal --post-hook '/etc/rc.d/nginx reload'" | doas tee -a /etc/monthly.local >/dev/null
