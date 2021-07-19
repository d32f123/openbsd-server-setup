#!/bin/sh

echo "Using ${USER_NAME:=$(whoami)} as main username"
echo "Using ${DOMAIN_NAME:=$(hostname | cut -d. -f2-)} as domain name"
export USER_NAME; export DOMAIN_NAME

BASE="$(pwd)"
SCRIPTS="$BASE/scripts"

"$SCRIPTS/001_bootstrap.sh"
"$SCRIPTS/002_shell.sh"
"$SCRIPTS/003_nginx.sh"