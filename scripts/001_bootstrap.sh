#!/bin/sh

# doas setup
echo "Enter your root password now to enable doas"
echo "echo 'permit nopass ${USER_NAME} as root' >> /etc/doas.conf" | su 

# dependencies
doas pkg_add \
  vim zsh zsh-syntax-highlighting bash curl wget git pkglocatedb rsync \
  nginx certbot \
  cmake gmake gcc g++ coreutils \
  base64 libqrencode

doas rcctl enable slaacd
doas rcctl start slaacd
