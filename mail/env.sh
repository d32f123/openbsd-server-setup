#!/bin/sh

[ -z "$DOMAIN_NAME" ] && DOMAIN_NAME="$(hostname | cut -d. -f2-)"
[ -z "$VMAIL_USER" ] && VMAIL_USER=vmail
[ -z "$VMAIL_UID" ] && VMAIL_UID="$(id -ru $VMAIL_USER)"
[ -z "$VMAIL_GID" ] && VMAIL_GID="$(id -rg $VMAIL_USER)"
[ -z "$VMAIL_ROOT" ] && VMAIL_ROOT=/var/vmail
[ -z "$CREDENTIALS" ] && CREDENTIALS=/etc/mail/credentials
[ -z "$VIRTUALS" ] && VIRTUALS=/etc/mail/virtuals

# Colors
RED="\033[0;31m"
YELLOW="\033[0;33m"
BOLD="\033[1m"
PURPLE="\033[0;35m"
NORM="\033[0m"
GREEN="\033[0;32m"