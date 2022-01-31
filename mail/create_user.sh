#!/bin/sh
# Creates a virtual user for mail
# Usage: create_user.sh <username> [<password>]
# Environment: DOMAIN_NAME, VMAIL_USER, VMAIL_UID, VMAIL_GID, VMAIL_ROOT, CREDENTIALS, VIRTUALS
ENVS="$(dirname $0)/../env.d"
. "$ENVS/general.sh"
. "$ENVS/mail.sh"

username="$1"
password="$2"
[ -z "$username" ] && prompt "Specify a user" "$USER_NAME " username
[ -z "$username" ] && panic "Username cannot be empty"

[ -z "$password" ] && prompt_password "Enter password for user $username:" password
[ -z "$password" ] && panic "Password cannot be empty"
encrypted_password=$(smtpctl encrypt "$password")
unset password

echo "${YELLOW}Creating user $username for domain $DOMAIN_NAME${NORM}"

echo "${username}@${DOMAIN_NAME}:${encrypted_password}:$VMAIL_USER:$VMAIL_UID:$VMAIL_GID:$VMAIL_ROOT/$DOMAIN_NAME/$username::userdb_mail=maildir:$VMAIL_ROOT/$DOMAIN_NAME/$username" | doas tee -a "$CREDENTIALS" >/dev/null
echo "${username}@${DOMAIN_NAME}: $VMAIL_USER" | doas tee -a "$VIRTUALS" >/dev/null

doas rcctl reload dovecot || panic "Failed to reload dovecot"
doas smtpctl update table credentials || panic "Failed to update table 'credentials'"
doas smtpctl update table virtuals || panic "Failed to update table 'virtuals'"

echo "${GREEN}User created${NORM}"
