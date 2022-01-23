#!/bin/sh
# Deletes a virtual mail user
# Usage: delete_user.sh <username>
ENVS="$(dirname $0)/../env.d"
. "$ENVS/general.sh"
. "$ENVS/mail.sh"

username="$1"
[ -z "$username" ] && prompt "Specify a user" "" username
[ -z "$username" ] && panic "Username cannot be empty"

echo "${YELLOW}Deleting user $username${NORM}"

doas grep "^$username@$DOMAIN_NAME" "$CREDENTIALS" >/dev/null || panic "User '$username' not found"
doas sed -i.bak -e "/$username@$DOMAIN_NAME/d" "$CREDENTIALS"
doas sed -i.bak -e "/$username@$DOMAIN_NAME/d" "$VIRTUALS"

doas rcctl reload dovecot || panic "Failed to reload dovecot"
doas smtpctl update table credentials || panic "Failed to reload credentials"
doas smtpctl update table virtuals || panic "Failed to reload virtuals"

echo "${GREEN}User $username deleted${NORM}"
