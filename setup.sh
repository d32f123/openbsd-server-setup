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

[ -n "$ssl_test" ] && export CERTBOT_FLAGS="--server https://{{local}}:14000/dir --no-verify-ssl"
i=0
for stage in bootstrap shell nginx ssl mail pf vpn
do
    i=$((i+1))
    [ -n "$run_all" ] || eval "[ -n \"\$run_$stage\" ]" && {
        echo "${YELLOW}${BOLD}---Stage $stage---${NORM}" | postinstall | log
        { 
            "$SCRIPTS/$(printf '%03d' $i)_$stage.sh" || {
                echo "${RED}${BOLD}[FATAL] Something went wrong here${NORM}" | postinstall
                exit 1
            }
        } | log
        echo "${YELLOW}${BOLD}---Stage $stage DONE---${NORM}" | postinstall | log
    }
done
