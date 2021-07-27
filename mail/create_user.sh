#!/bin/sh
# Creates a virtual user for mail
# Usage: create_user.sh <username> [<password>]
# Environment: DOMAIN_NAME, VMAIL_USER, VMAIL_UID, VMAIL_GID, VMAIL_ROOT, CREDENTIALS, VIRTUALS
username="$1"
password="$2"

[ -z "$DOMAIN_NAME" ] && DOMAIN_NAME="$(hostname | cut -d. -f2-)"
echo "Creating user $username for domain $DOMAIN_NAME"

[ -z "$VMAIL_USER" ] && VMAIL_USER=vmail
[ -z "$VMAIL_UID" ] && VMAIL_UID="$(id -ru $VMAIL_USER)"
[ -z "$VMAIL_GID" ] && VMAIL_GID="$(id -rg $VMAIL_USER)"
[ -z "$VMAIL_ROOT" ] && VMAIL_ROOT=/var/vmail
[ -z "$CREDENTIALS" ] && CREDENTIALS=/etc/mail/credentials
[ -z "$VIRTUALS" ] && VIRTUALS=/etc/mail/virtuals

encrypted_password=$([ -z "$password" ] && { echo "Enter password for user $username: \c" >/dev/tty ; stty -echo ; read password ; stty echo ; echo >/dev/tty ; } ; smtpctl encrypt "$password")
unset password

echo "${username}@${DOMAIN_NAME}:${encrypted_password}:$VMAIL_USER:$VMAIL_UID:$VMAIL_GID:$VMAIL_ROOT/$DOMAIN_NAME/$username::userdb_mail=maildir:$VMAIL_ROOT/$DOMAIN_NAME/$username" | doas tee -a "$CREDENTIALS"
echo "${username}@${DOMAIN_NAME}: $VMAIL_USER" | doas tee -a "$VIRTUALS"
