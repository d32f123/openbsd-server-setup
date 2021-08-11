#!/bin/sh
# Changes password for an already created virtual mail user
# Usage: change_password.sh <user> [<password>]
username="$1"
password="$2"
[ -z "$username" ] && echo "${RED}Specify a user${NORM}" && exit 1

d="$(dirname $0)"

. $d/env.sh
echo "${YELLOW}Changing password for user $username${NORM}"

encrypted_password=$([ -z "$password" ] && { echo "${PURPLE}${BOLD}Enter password for user $username: ${NORM}\c" >/dev/tty ; stty -echo ; read password ; stty echo ; echo >/dev/tty ; } ; smtpctl encrypt "$password")
unset password

doas grep "^$username@$DOMAIN_NAME" "$CREDENTIALS" >/dev/null || { echo "${RED}User not found" ; exit 1 ; }
doas sed -i.bak -E "s?$username@$DOMAIN_NAME:[^:]+?$username@$DOMAIN_NAME:$encrypted_password?" "$CREDENTIALS" && echo "${GREEN}Password changed${NORM}"

doas rcctl reload dovecot || {
    echo "${RED}Failed to reload dovecot${NORM}"
    exit 1
}
doas smtpctl update table credentials