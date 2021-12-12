#!/bin/sh

MAIL_CONF_DIR=/etc/mail
MAIL_CONF=$MAIL_CONF_DIR/smtpd.conf
CERT_DIR="/etc/letsencrypt/live/$MAIL_DOMAIN"

doas [ ! -d "$CERT_DIR" ] && echo "${RED}Get an SSL certificate for $MAIL_DOMAIN first${NORM}" && exit 1

echo "${YELLOW}Creating vmail account${NORM}"
VMAIL_USER=vmail
VMAIL_ROOT=/var/vmail
doas useradd -c "Virtual Mail Account" -d $VMAIL_ROOT -s /sbin/nologin -L staff $VMAIL_USER

VMAIL_UID="$(id -ru $VMAIL_USER)"
VMAIL_GID="$(id -rg $VMAIL_USER)"

echo "${YELLOW}Configuring smtpd $MAIL_CONF${NORM}"
doas cp -f $MAIL_CONF_DIR/{smtpd.conf,smtpd.bak.conf}
sed "s/{{base_domain}}/$DOMAIN_NAME/g; 
     s/{{mail_domain}}/$MAIL_DOMAIN/g;
     s/{{vmail_user}}/$VMAIL_USER/g;" mail/smtpd.template.conf | doas tee $MAIL_CONF >/dev/null

CREDENTIALS=$MAIL_CONF_DIR/credentials
VIRTUALS=$MAIL_CONF_DIR/virtuals
ALIASES=$MAIL_CONF_DIR/aliases

echo "$MAIL_DOMAIN" | doas tee $MAIL_CONF_DIR/mailname >/dev/null

export CREDENTIALS VIRTUALS ALIASES VMAIL_USER VMAIL_UID VMAIL_GID VMAIL_ROOT

for f in $CREDENTIALS $VIRTUALS $ALIASES; do
    doas touch $f
    doas chmod 0440 $f
done
doas chown _smtpd:_dovecot $CREDENTIALS

doas mkdir $VMAIL_ROOT
doas chown $VMAIL_USER:$VMAIL_USER $VMAIL_ROOT

echo "${YELLOW}Making a specialized login group for dovecot${NORM}"
echo "dovecot:\\
    :openfiles-cur=1024:\\
    :openfiles-max=2048:\\
    :tc=daemon:" | doas tee -a /etc/login.conf >/dev/null
doas usermod -L dovecot _dovecot
doas cap_mkdb /etc/login.conf # update login.conf db

# Disable ssl file since we already put ssl info in local.conf
doas mv /etc/dovecot/conf.d/10-ssl.conf /etc/dovecot/conf.d/10-ssl.conf.disabled
doas rcctl restart dovecot || doas rcctl restart dovecot || doas rcctl restart dovecot || {
    echo "${RED}Dovecot failed to start${NORM}"
    exit 1
}

echo "${YELLOW}Creating virtual user $USER_NAME${NORM}"
mail/create_user.sh $USER_NAME || {
    echo "${RED}Failed to create user $USER_NAME${NORM}"
    exit 1
}

main_user_mail_aliases="root abuse hostmaster postmaster webmaster"
echo "${YELLOW}Adding aliases $main_user_mail_aliases for $USER_NAME${NORM}"
for aliass in $main_user_mail_aliases; do
    echo "$aliass@$DOMAIN_NAME: $USER_NAME@$DOMAIN_NAME" | doas tee -a "$VIRTUALS" >/dev/null
    case "$aliass" in
        root|hostmaster|webmaster) echo "$aliass: $USER_NAME" | doas tee -a "$ALIASES" >/dev/null ;;
    esac
done
echo "$USER_NAME: $USER_NAME@$DOMAIN_NAME" | doas tee -a "$ALIASES" >/dev/null
doas newaliases

# TODO: Prompt to add additional virtual users

echo "${YELLOW}Restarting smtpd service${NORM}"
doas rcctl enable smtpd
doas rcctl restart smtpd || {
    echo "${RED}Failed to restart smtpd server${NORM}"
    exit 1
}

echo "${YELLOW}Configuring Dovecot${NORM}"

SIEVE_ROOT=/usr/local/lib/dovecot/sieve
spam_script=$SIEVE_ROOT/report-spam.sieve
ham_script=$SIEVE_ROOT/report-ham.sieve

sed "s/{{mail_domain}}/$MAIL_DOMAIN/g; 
     s?{{credentials}}?$CREDENTIALS?g; 
     s/{{vmail_uid}}/$VMAIL_UID/g; 
     s/{{vmail_gid}}/$VMAIL_GID/g;
     s?{{vmail_root}}?$VMAIL_ROOT?g;
     s?{{spam_script}}?$spam_script?g;
     s?{{ham_script}}?$ham_script?g;" mail/dovecot.template.conf | doas tee /etc/dovecot/local.conf >/dev/null

doas cp mail/report-ham.sieve mail/report-spam.sieve $SIEVE_ROOT
doas chown root:bin $ham_script $spam_script

echo "${YELLOW}Compiling spam and ham Sieve scripts${NORM}"
doas sievec $ham_script
doas sievec $spam_script

doas cp mail/sa-learn-ham.sh mail/sa-learn-spam.sh $SIEVE_ROOT
doas chown root:bin $SIEVE_ROOT/sa-learn-ham.sh $SIEVE_ROOT/sa-learn-spam.sh

echo "${YELLOW}Restarting dovecot service${NORM}"
doas rcctl enable dovecot
doas rcctl restart dovecot || {
    echo "${RED}Failed to load dovecot with the new configuration${NORM}"
    exit 1
}

echo "${YELLOW}Configuring spamd"
doas mkdir $MAIL_CONF_DIR/dkim
doas opendkim-genkey -D $MAIL_CONF_DIR/dkim -d "$DOMAIN_NAME" -s "$MAIL_DOMAIN"
DKIM_SECRET_KEY="$MAIL_CONF_DIR/dkim/${MAIL_DOMAIN}.private"
DKIM_PUBLIC_KEY="$MAIL_CONF_DIR/dkim/${MAIL_DOMAIN}.txt"
doas chown root:_rspamd "$DKIM_SECRET_KEY"
doas chmod 0440 "$DKIM_SECRET_KEY"
doas chmod 0444 "$DKIM_PUBLIC_KEY"

dns_dkim_record="$(<$DKIM_PUBLIC_KEY)"
dns_spf_record="@ TXT v=spf1 mx a:$MAIL_DOMAIN -all"
dns_dmarc_record="_dmarc.$DOMAIN_NAME TXT v=DMARC1; p=reject; rua=mailto:postmaster@$DOMAIN_NAME;"
dns_records="$dns_dkim_record
$dns_spf_record
$dns_dmarc_record
_imap._tcp.$DOMAIN_NAME.	300	IN	SRV	0 0 0 .
_imaps._tcp.$DOMAIN_NAME.	300	IN	SRV	10 1 993 $MAIL_DOMAIN.
_pop3._tcp.$DOMAIN_NAME.	300	IN	SRV	0 0 0 .
_pop3s._tcp.$DOMAIN_NAME.	300	IN	SRV	0 0 0 .
_submission._tcp.$DOMAIN_NAME.	300	IN	SRV	20 1 587 $MAIL_DOMAIN.
_submission._tcp.$DOMAIN_NAME.	300	IN	SRV	30 1 25 $MAIL_DOMAIN.
_submissions._tcp.$DOMAIN_NAME.	300	IN	SRV	10 1 465 $MAIL_DOMAIN.
"
# TODO: Add a cronjob to rotate dkim keys every 3 months

echo "$dns_records" >~/dns_records.txt

doas mkdir -p /etc/rspamd/local.d
sed "s/{{domain}}/$DOMAIN_NAME/g;
     s?{{dkim_private_key}}?$DKIM_SECRET_KEY?g; 
     s/{{dkim_selector}}/$MAIL_DOMAIN/g;" mail/dkim_signing.template.conf | doas tee /etc/rspamd/local.d/dkim_signing.conf >/dev/null

echo "${YELLOW}Restarting rspamd service${NORM}"
doas rcctl enable redis rspamd
doas rcctl start redis rspamd || {
    echo "${RED}Failed to restart rspamd${NORM}"
    exit 1
}

if [ -n "$DO_RAINLOOP" ]; then
    echo "${YELLOW}Installing RainLoop${NORM}"
    doas pkg_add php php-curl php-pdo_sqlite php-zip zip unzip
    cd $(mktemp -d)
    wget https://www.rainloop.net/repository/webmail/rainloop-latest.zip
    doas unzip rainloop-latest.zip -d /var/www/$MAIL_DOMAIN/
    cd -
    doas find /var/www/$MAIL_DOMAIN -type d -exec chmod 755 {} \;
    doas find /var/www/$MAIL_DOMAIN -type f -exec chmod 644 {} \;
    doas chown -R www:www /var/www/$MAIL_DOMAIN

    echo "${YELLOW}Modifying NGINX configuration for $MAIL_DOMAIN${NORM}"
    doas sed -i.pre_rainloop '
    s/index.html/index.php/;
    /include secure;/a\
    client_max_body_size 25M;\
\
    location ^~ /data {\
        deny all;\
    }\
\
    location ~ [^/]\.php(/|$) {\
        include fastcgi_params;\
        try_files $uri $uri/ =404;\
        fastcgi_split_path_info ^(.+?\.php)(/.*)$;\
        if (!-f $document_root$fastcgi_script_name) {\
            return 404;\
        }\
        fastcgi_param HTTP_PROXY "";\
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;\
        fastcgi_index index.php;\
        fastcgi_pass unix:run/php-fpm.sock;\
    }\
' /etc/nginx/sites-available/$MAIL_DOMAIN.secure.site
    doas nginx -s reload

    echo "${YELLOW}Configuring RainLoop${NORM}"
    PHP_VERSION=$(ls -d /etc/php-*.sample | head -1 | sed -E 's/.*php-(.*)\.sample/\1/')
    doas sed -i.bak -e 's/upload_max_filesize =.*$/upload_max_filesize = 25M/;
    s/post_max_size =.*$/post_max_size = 29M/;' /etc/php-$PHP_VERSION.ini
    doas cp /etc/php-$PHP_VERSION.sample/* /etc/php-$PHP_VERSION/.

    FPM_SERVICE=$(rcctl ls all | grep 'php.*_fpm' | head -1)
    doas rcctl enable $FPM_SERVICE
    doas rcctl start $FPM_SERVICE
    doas mkdir /var/www/etc
    doas ln /etc/resolv.conf /var/www/etc/resolv.conf

    # This is to generate the RainLoop directories
    wget -O /dev/null $MAIL_DOMAIN
    RAINLOOP_ROOT=/var/www/$MAIL_DOMAIN/data/_data_/_default_

    doas sed -e "s/{{domain}}/$DOMAIN_NAME/;" mail/application.template.ini | doas tee $RAINLOOP_ROOT/configs/application.ini >/dev/null
    doas chown www:www $RAINLOOP_ROOT/configs/application.ini

    doas sed -e "s/{{mail_domain}}/$MAIL_DOMAIN/" mail/domain.template.ini | doas tee $RAINLOOP_ROOT/domains/$DOMAIN_NAME.ini >/dev/null
    doas chown www:www $RAINLOOP_ROOT/domains/$DOMAIN_NAME.ini

    echo "${BOLD}${PURPLE}RainLoop is available at: https://$MAIL_DOMAIN/"
fi


echo "${BOLD}${PURPLE}----MAIL CONFIGURATION DONE----"
echo "${BOLD}${PURPLE}Now place these entries in your DNS records:
$NORM$PURPLE$dns_records
$NORM
"