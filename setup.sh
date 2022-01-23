#!/bin/sh
# Usage: ./setup.sh [bootstrap] [shell] [nginx] [ssl [--ssl-test]] [mail] [pf] [vpn]
#   By default runs all

run_all=yes
for arg in "$@"; do
    case "$arg" in
        --ssl-test) ssl_test=yes ; continue ;;
    esac
    unset run_all
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

# ----
BASE="$(pwd)"
SCRIPTS="$BASE/scripts"
ENVS="$BASE/env.d"
. "$ENVS/general.sh"

echo -n "${YELLOW}${BOLD}"
echo "User: $USER_NAME"
echo "Base domain name: $DOMAIN_NAME"
echo "Mail domain name: $MAIL_DOMAIN"
echo "VPN domain name: $VPN_DOMAIN"
echo -n "${NORM}"

[ -n "$run_all" ] || [ -n "$run_bootstrap" ] && { "$SCRIPTS/001_bootstrap.sh" || exit 1 ; }
[ -n "$run_all" ] || [ -n "$run_shell" ] && { "$SCRIPTS/002_shell.sh" || exit 1 ; }
[ -n "$run_all" ] || [ -n "$run_nginx" ] && { "$SCRIPTS/003_nginx.sh" || exit 1 ; }
[ -n "$run_all" ] || [ -n "$run_ssl" ] && {
    [ -n "$ssl_test" ] && export CERTBOT_FLAGS="--server https://{{local}}:14000/dir --no-verify-ssl"
    "$SCRIPTS/004_ssl.sh" || exit 1
}
[ -n "$run_all" ] || [ -n "$run_mail" ] && { "$SCRIPTS/005_mail.sh" || exit 1 ; }
[ -n "$run_all" ] || [ -n "$run_pf" ] && { "$SCRIPTS/006_pf.sh" || exit 1 ; }
[ -n "$run_all" ] || [ -n "$run_vpn" ] && { "$SCRIPTS/007_vpn.sh" || exit 1 ; }
