#!/bin/sh
# Changes password for an already created virtual mail user
# Usage: change_password.sh <user> [<password>]
ENVS="$(dirname $0)/../env.d"
. "$ENVS/general.sh"
. "$ENVS/mail.sh"

username="$1"
password="$2"
[ -z "$username" ] && prompt "Specify a user" "" username
[ -z "$username" ] && panic "Username cannot be empty"

[ -z "$password" ] && prompt_password "Enter password for user $username:" password
[ -z "$password" ] && panic "Password cannot be empty"
encrypted_password=$(smtpctl encrypt "$password")
unset password

echo "${YELLOW}Changing password for user $username${NORM}"

doas grep "^$username@$DOMAIN_NAME" "$CREDENTIALS" >/dev/null || panic "User '$username' not found"
doas sed -i.bak -E "s?$username@$DOMAIN_NAME:[^:]+?$username@$DOMAIN_NAME:$encrypted_password?" "$CREDENTIALS" && echo "${GREEN}Password changed${NORM}"

doas rcctl reload dovecot || panic "Failed to reload dovecot"
doas smtpctl update table credentials || panic "Failed to update credentials table"
