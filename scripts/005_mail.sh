#!/bin/sh

MAIL_CONF_DIR=/etc/mail
MAIL_CONF=$MAIL_CONF_DIR/smtpd.conf
CERT_DIR="/etc/letsencrypt/live/$MAIL_DOMAIN"

doas [ ! -d "$CERT_DIR" ] && echo "Get an SSL certificate for $MAIL_DOMAIN first" && exit 1

echo "Downloading dependencies for mail"
doas pkg_add opensmtpd-extras opensmtpd-filter-senderscore opensmtpd-filter-rspamd opendkim dovecot dovecot-pigeonhole rspamd redis

echo "Creating vmail account"
VMAIL_USER=vmail
VMAIL_ROOT=/var/vmail
doas useradd -c "Virtual Mail Account" -d $VMAIL_ROOT -s /sbin/nologin -L staff $VMAIL_USER

VMAIL_UID="$(id -ru $VMAIL_USER)"
VMAIL_GID="$(id -rg $VMAIL_USER)"

echo "Creating configuration at $MAIL_CONF"
doas cp -f $MAIL_CONF/{smtpd.conf,smtpd.bak.conf}
sed "s/{{base_domain}}/$DOMAIN_NAME/g; 
     s/{{mail_domain}}/$MAIL_DOMAIN/g;
     s/{{vmail_user}}/$VMAIL_USER/g;" mail/smtpd.template.conf | doas tee $MAIL_CONF

CREDENTIALS=$MAIL_CONF_DIR/credentials
VIRTUALS=$MAIL_CONF_DIR/virtuals
ALIASES=$MAIL_CONF_DIR/aliases

echo "$MAIL_DOMAIN" | doas tee $MAIL_CONF/mailname

export CREDENTIALS VIRTUALS ALIASES VMAIL_USER VMAIL_UID VMAIL_GID VMAIL_ROOT

for f in $CREDENTIALS $VIRTUALS $ALIASES; do
    doas touch $f
    doas chmod 0440 $f
    doas chown _smtpd:_dovecot $f
done

doas mkdir $VMAIL_ROOT
doas chown $VMAIL_USER:$VMAIL_USER $VMAIL_ROOT

echo "Creating virtual user $USER_NAME"
mail/create_user.sh $USER_NAME

main_user_mail_aliases="root abuse hostmaster postmaster webmaster"
echo "Adding aliases $main_user_mail_aliases for $USER_NAME"
for aliass in $main_user_mail_aliases; do
    echo "$aliass@$DOMAIN_NAME: $USER_NAME@$DOMAIN_NAME" | doas tee -a "$VIRTUALS"
    case "$aliass" in
        root|hostmaster|webmaster) echo "$aliass: $USER_NAME" | doas tee -a "$ALIASES" ;;
    esac
done
doas newaliases

# TODO: Prompt to add additional virtual users

echo "Restarting smtpd service"
doas rcctl enable smtpd
doas rcctl restart smtpd

echo "Setting up Dovecot"

echo "dovecot:\\
    :openfiles-cur=1024:\\
    :openfiles-max=2048:\\
    :tc=daemon:" | doas tee -a /etc/login.conf

SIEVE_ROOT=/usr/local/lib/dovecot/sieve
spam_script=$SIEVE_ROOT/report-spam.sieve
ham_script=$SIEVE_ROOT/report-ham.sieve

sed "s/{{mail_domain}}/$MAIL_DOMAIN/g; 
     s?{{credentials}}?$CREDENTIALS?g; 
     s/{{vmail_uid}}/$VMAIL_UID/g; 
     s/{{vmail_gid}}/$VMAIL_GID/g;
     s?{{vmail_root}}?$VMAIL_ROOT?g;
     s?{{spam_script}}?$spam_script?g;
     s?{{ham_script}}?$ham_script?g;" mail/dovecot.template.conf | doas tee /etc/dovecot/local.conf

doas cp mail/report-ham.sieve mail/report-spam.sieve $SIEVE_ROOT
doas chown root:bin $ham_script $spam_script

doas sievec $ham_script
doas sievec $spam_script

doas cp mail/sa-learn-ham.sh mail/sa-learn-spam.sh $SIEVE_ROOT
doas chown root:bin $SIEVE_ROOT/sa-learn-ham.sh $SIEVE_ROOT/sa-learn-spam.sh

# Disable ssl file since we already put ssl info in local.conf
doas mv /etc/dovecot/conf.d/10-ssl.conf /etc/dovecot/conf.d/10-ssl.conf.disabled

echo "Restarting dovecot service"
doas rcctl enable dovecot
doas rcctl restart dovecot

echo "Setting up spamd"
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
$dns_dmarc_record"


echo "$dns_records" >dns_records.txt

doas mkdir -p /etc/rspamd/local.d
sed "s/{{domain}}/$DOMAIN_NAME/g;
     s?{{dkim_private_key}}?$DKIM_SECRET_KEY?g; 
     s/{{dkim_selector}}/$MAIL_DOMAIN/g;" mail/dkim_signing.template.conf | doas tee /etc/rspamd/local.d/dkim_signing.conf

doas rcctl enable redis rspamd
doas rcctl start redis rspamd

echo "----MAIL CONFIGURATION DONE----"
echo "Now place these entries in your DNS records:
$dns_records
"