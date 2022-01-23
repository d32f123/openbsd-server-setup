#!/bin/sh

prompt() {
    prompt="$1"
    default="$2"
    result="$3"
    echo "${PURPLE}${BOLD}$prompt [$default] ${NORM}\c"
    read "$result"
    [ -z "$(eval echo \$$result)" ] && eval "$result=$default"
}

prompt_bool() {
    prompt="$1"
    default="$2"
    echo "${PURPLE}${BOLD}$prompt (y/n) [$default] ${NORM}\c"
    read res
    case "$res" in
        y | yes | Y | YES) return 0;;
    esac
    return 1
}

prompt_password() {
    prompt="$1"
    result="$2"
    echo "${PURPLE}${BOLD}$prompt ${NORM}\c"
    stty -echo
    read "$result"
    stty echo
    echo
}

panic() {
    msg="$1"
    echo "${RED}${BOLD}$msg${NORM}"
    exit 1
}

# Colors
RED="\033[0;31m"
YELLOW="\033[0;33m"
BOLD="\033[1m"
PURPLE="\033[0;35m"
GREEN="\033[0;32m"
NORM="\033[0m"
export RED YELLOW BOLD PURPLE GREEN NORM

[ -z "$USER_NAME" ] && USER_NAME="$(whoami)"
[ -z "$DOMAIN_NAME" ] && DOMAIN_NAME="$(hostname | cut -d. -f2-)"
[ -z "$MAIL_DOMAIN" ] && MAIL_DOMAIN="mail.$DOMAIN_NAME"
[ -z "$VPN_DOMAIN" ] && VPN_DOMAIN="vpn.$DOMAIN_NAME"
NGINX_DOMAINS="$DOMAIN_NAME $MAIL_DOMAIN $VPN_DOMAIN"
export USER_NAME DOMAIN_NAME MAIL_DOMAIN VPN_DOMAIN NGINX_DOMAINS
