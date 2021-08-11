#!/bin/sh
# Deletes a virtual mail user
# Usage: delete_user.sh <username>
username="$1"
[ -z "$username" ] && echo "${RED}Specify a user${NORM}" && exit 1

d="$(dirname $0)"

. $d/env.sh
echo "${YELLOW}Deleting user $username${NORM}"

doas grep "^$username@$DOMAIN_NAME" "$CREDENTIALS" >/dev/null || { echo "${RED}User not found${NORM}" ; exit 1 ; }
doas sed -i.bak -e "/$username@$DOMAIN_NAME/d" "$CREDENTIALS"
doas sed -i.bak -e "/$username@$DOMAIN_NAME/d" "$VIRTUALS"

doas rcctl reload dovecot || {
    echo "${RED}Failed to reload dovecot${NORM}"
    exit 1
}
doas smtpctl update table credentials
doas smtpctl update table virtuals

echo "${GREEN}User $username deleted${NORM}"