#!/bin/sh

# Usage: ./setup.sh [bootstrap] [shell] [nginx] [ssl] [mail] [pf] [vpn]
#   By default runs all

run_all=yes
[ -z "$*" ] || unset run_all
for arg in "$@"; do
    case "$arg" in
        bootstrap) run_bootstrap=yes ;;
        shell) run_shell=yes ;;
        nginx) run_nginx=yes ;;
        ssl) run_ssl=yes ;;
        mail) run_mail=yes ;;
        pf) run_pf=yes ;;
        vpn) run_vpn=yes ;;
    esac
done

prompt_user() {
    prompt="$1"
    default="$2"
    result="$3"
    echo "${PURPLE}${BOLD}$prompt [$default] ${NORM}\c"
    read "$result"
    [ -z "$(eval echo \$$result)" ] && eval "$result=$default"
}
export prompt_user

# Colors
RED="\033[0;31m"
YELLOW="\033[0;33m"
BOLD="\033[1m"
PURPLE="\033[0;35m"
GREEN="\033[0;32m"
NORM="\033[0m"
export RED YELLOW BOLD PURPLE GREEN NORM

# ----
[ -z "$USER_NAME" ] && prompt_user "Which user should become the main user?" "$(whoami)" USER_NAME
[ -z "$DOMAIN_NAME" ] && prompt_user "Please enter the domain name of your server." "$(hostname | cut -d. -f2-)" DOMAIN_NAME
echo "${YELLOW}Using ${USER_NAME} as main username"
echo "${YELLOW}Using ${DOMAIN_NAME} as domain name"
export USER_NAME; export DOMAIN_NAME

[ -z "$MAIN_DOMAIN" ] && prompt_user "Mail domain:" "mail.$DOMAIN_NAME" MAIL_DOMAIN
export MAIL_DOMAIN

[ -z "$VPN_DOMAIN" ] && prompt_user "VPN domain:" "vpn.$DOMAIN_NAME" VPN_DOMAIN
export VPN_DOMAIN

NGINX_DOMAINS="$DOMAIN_NAME $MAIL_DOMAIN $VPN_DOMAIN"
echo "${YELLOW}Will setup these domains: $NGINX_DOMAINS"
export NGINX_DOMAINS

BASE="$(pwd)"
SCRIPTS="$BASE/scripts"

[ -n "$run_all" ] || [ -n "$run_bootstrap" ] && { "$SCRIPTS/001_bootstrap.sh" || exit 1 ; }
[ -n "$run_all" ] || [ -n "$run_shell" ] && { "$SCRIPTS/002_shell.sh" || exit 1 ; }
[ -n "$run_all" ] || [ -n "$run_nginx" ] && { "$SCRIPTS/003_nginx.sh" || exit 1 ; }
[ -n "$run_all" ] || [ -n "$run_ssl" ] && { "$SCRIPTS/004_ssl.sh" || exit 1 ; }
[ -n "$run_all" ] || [ -n "$run_mail" ] && { "$SCRIPTS/005_mail.sh" || exit 1 ; }
[ -n "$run_all" ] || [ -n "$run_pf" ] && { "$SCRIPTS/006_pf.sh" || exit 1 ; }
[ -n "$run_all" ] || [ -n "$run_vpn" ] && { 
    prompt_user "Set up IKEv2? It is less secure than WireGuard (yes/no)" "no" DO_IKEV2
    [ "$DO_IKEV2" = "yes" ] || unset DO_IKEV2
    export DO_IKEV2
    "$SCRIPTS/007_vpn.sh" || exit 1
}
