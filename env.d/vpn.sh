#!/bin/sh

MAIN_IF="$(ls /etc/hostname.* | grep -v enc | grep -v wg | head -1 | cut -d. -f 2)"
MAIN_IP="$(ifconfig $MAIN_IF | grep inet | grep -v inet6 | cut -d' ' -f2)"
MAIN_IP6="$(ifconfig $MAIN_IF | grep inet6 | grep -v '%' | cut -d' ' -f2)"

VPN_USER=vpn

[ -z "$WG_IF" ] && WG_IF=wg0
[ -z "$WG_NET" ] && {
    WG_IP=$(ifconfig $WG_IF | grep -E 'inet[^6]' | cut -d' ' -f 2)
    WG_NETMASK=$(ifconfig $WG_IF | grep -E 'inet[^6]' | sed -nE 's/^.*netmask ([^ ]+)($| .*$)/\1/p')
    WG_PREFIX=$(ipcalc $WG_IP / $WG_NETMASK | grep network | cut -d'/' -f2)

    WG_NET=$WG_IP/$WG_PREFIX
}
[ -z "$WG_NET6" ] && {
    WG_IP6=$(ifconfig $WG_IF | grep 'inet6 ' | tail -1 | cut -d' ' -f 2)
    WG_PREFIX6=$(ifconfig $WG_IF | grep 'inet6 ' | tail -1 | sed -nE 's/^.*prefixlen ([^ ]+)($| .*$)/\1/p')
    WG_NET6="$WG_IP6 $WG_PREFIX6"
}
[ -z "$WG_PUBKEY" ] && WG_PUBKEY=$(doas ifconfig $WG_IF | grep wgpubkey | cut -d' ' -f2)
[ -z "$WG_PORT" ] && WG_PORT=$(doas ifconfig $WG_IF | grep wgport | cut -d' ' -f2)
