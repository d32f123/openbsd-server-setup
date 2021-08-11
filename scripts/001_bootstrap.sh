#!/bin/sh

# doas setup
echo "${PINK}${BOLD}Enter your root password now to enable doas${NORM}"
echo "echo 'permit nopass ${USER_NAME} as root' >> /etc/doas.conf" | su 

# dependencies
echo "${YELLOW}Downloading dependencies${NORM}"
doas pkg_add \
  vim zsh zsh-syntax-highlighting bash curl wget git pkglocatedb rsync \
  nginx certbot \
  cmake gmake gcc g++ coreutils \
  base64 libqrencode \
  wireguard-tools ipcalc \
  opensmtpd-extras opensmtpd-filter-senderscore opensmtpd-filter-rspamd \
  opendkim dovecot dovecot-pigeonhole rspamd redis || {
    echo "${RED}Failed to download dependencies!${NORM}"
    exit 1
  }

echo "${YELLOW}Enabling slaacd for IPv6${NORM}"
doas rcctl enable slaacd
doas rcctl start slaacd
