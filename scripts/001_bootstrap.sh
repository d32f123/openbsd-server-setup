#!/bin/sh

# doas setup
echo -n "${PINK}${BOLD}Enter your root password now to enable doas... ${NORM}"
echo "echo 'permit nopass ${USER_NAME} as root' >> /etc/doas.conf" | su 

echo "${YELLOW}Enabling slaacd for IPv6${NORM}"
doas rcctl enable slaacd
doas rcctl start slaacd
