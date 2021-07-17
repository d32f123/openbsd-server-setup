#!/bin/sh

echo "Using ${USER_NAME:=$(whoami)} as main username"
echo "Using ${DOMAIN_NAME:=$(hostname | cut -d. -f2-)} as domain name"
export USER_NAME; export DOMAIN_NAME

BASE="$(pwd)"
SCRIPTS="$BASE/scripts"

"$SCRIPTS/bootstrap.sh"
"$SCRIPTS/shell.sh"
