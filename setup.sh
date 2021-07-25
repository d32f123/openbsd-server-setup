#!/bin/sh

# Usage: ./setup.sh [bootstrap] [shell] [nginx] [ssl] [mail]
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
    esac
done

prompt_user() {
    prompt="$1"
    default="$2"
    result="$3"
    echo "$prompt [$default] \c"
    read "$result"
    [ -z "$answer" ] && eval "$result=$default"
}

[ -z "$USER_NAME" ] && prompt_user "Which user should become the main user?" "$(whoami)" USER_NAME
[ -z "$DOMAIN_NAME" ] && prompt_user "Please enter the domain name of your server." "$(hostname | cut -d. -f2-)" DOMAIN_NAME
echo "Using ${USER_NAME} as main username"
echo "Using ${DOMAIN_NAME} as domain name"
export USER_NAME; export DOMAIN_NAME

NGINX_DOMAINS="$DOMAIN_NAME mail.$DOMAIN_NAME"
echo "Will setup these domains: $NGINX_DOMAINS"
export NGINX_DOMAINS

BASE="$(pwd)"
SCRIPTS="$BASE/scripts"

[ -n "$run_all" ] || [ -n "$run_bootstrap" ] && "$SCRIPTS/001_bootstrap.sh"
[ -n "$run_all" ] || [ -n "$run_shell" ] && "$SCRIPTS/002_shell.sh"
[ -n "$run_all" ] || [ -n "$run_nginx" ] && "$SCRIPTS/003_nginx.sh"
[ -n "$run_all" ] || [ -n "$run_ssl" ] &&  "$SCRIPTS/004_ssl.sh"
[ -n "$run_all" ] || [ -n "$run_mail" ] &&  "$SCRIPTS/005_mail.sh"