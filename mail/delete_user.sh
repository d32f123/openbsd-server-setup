#!/bin/sh
# Deletes a virtual mail user
# Usage: delete_user.sh <username>
username="$1"
[ -z "$username" ] && echo "Specify a user" && exit 1

d="$(dirname $0)"

. $d/env.sh
echo "Deleting user $username"

doas grep "^$username@$DOMAIN_NAME" "$CREDENTIALS" >/dev/null || { echo "User not found" ; exit 1 ; }
doas sed -i.bak -e "/$username@$DOMAIN_NAME/d" "$CREDENTIALS"
doas sed -i.bak -e "/$username@$DOMAIN_NAME/d" "$VIRTUALS"
echo "User $username deleted"

doas rcctl reload dovecot
doas smtpctl update table credentials
doas smtpctl update table virtuals
