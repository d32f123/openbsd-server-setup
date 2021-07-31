#!/bin/sh
# Creates a virtual user for mail
# Usage: create_user.sh <username> [<password>]
# Environment: DOMAIN_NAME, VMAIL_USER, VMAIL_UID, VMAIL_GID, VMAIL_ROOT, CREDENTIALS, VIRTUALS
username="$1"
password="$2"
[ -z "$username" ] && echo "Specify a user" && exit 1

d="$(dirname $0)"

. $d/env.sh
echo "Creating user $username for domain $DOMAIN_NAME"


encrypted_password=$([ -z "$password" ] && { echo "Enter password for user $username: \c" >/dev/tty ; stty -echo ; read password ; stty echo ; echo >/dev/tty ; } ; smtpctl encrypt "$password")
unset password

echo "${username}@${DOMAIN_NAME}:${encrypted_password}:$VMAIL_USER:$VMAIL_UID:$VMAIL_GID:$VMAIL_ROOT/$DOMAIN_NAME/$username::userdb_mail=maildir:$VMAIL_ROOT/$DOMAIN_NAME/$username" | doas tee -a "$CREDENTIALS"
echo "${username}@${DOMAIN_NAME}: $VMAIL_USER" | doas tee -a "$VIRTUALS"

doas rcctl reload dovecot
doas smtpctl update table credentials
doas smtpctl update table virtuals
