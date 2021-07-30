#!/bin/sh
# Changes password for an already created virtual mail user
# Usage: change_password.sh <user> [<password>]
username="$1"
password="$2"
[ -z "$username" ] && echo "Specify a user" && exit 1

d="$(dirname $0)"

. $d/env.sh
echo "Changing password for user $username"

encrypted_password=$([ -z "$password" ] && { echo "Enter password for user $username: \c" >/dev/tty ; stty -echo ; read password ; stty echo ; echo >/dev/tty ; } ; smtpctl encrypt "$password")
unset password

doas grep "^$username@$DOMAIN_NAME" "$CREDENTIALS" >/dev/null || { echo "User not found" ; exit 1 ; }
doas sed -i.bak -E "s?$username@$DOMAIN_NAME:[^:]+?$username@$DOMAIN_NAME:$encrypted_password?" "$CREDENTIALS" && echo "Password changed"

doas rcctl reload dovecot
