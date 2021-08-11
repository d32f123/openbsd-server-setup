#!/bin/sh
# Creates a new WireGuard VPN client
# Usage: wg_create_user.sh <username>
# Script will spew out a QR Code and a link to the WireGuard configuration.
# The link will be invalidated at midnight by a cronjob which is set up during 007_vpn.sh
usage="Usage: wg_create_user.sh <username>"

username="$1"
[ -z "$username" ] && echo "${RED}$usage${NORM}" && exit 1

d="$(dirname $0)"

. $d/env.sh
echo "${YELLOW}Creating user $username for $VPN_DOMAIN${NORM}"

www_secret="$(openssl rand -base64 32 | ghead -c 20)"
key="$(openssl rand -base64 32)"
psk=$(openssl rand -base64 32)

# Set up a temporary interface wg9 to get the public key (hopefully it is not configured since it will be destroyed)
temp_if=wg9
temp_port=51821
temp_addr=10.2.134.134
doas ifconfig $temp_if wgport $temp_port wgkey "$key"

pubkey="$(doas ifconfig $temp_if | grep wgpubkey | cut -d' ' -f2)"
doas ifconfig $temp_if destroy

peers=$(doas ifconfig $WG_IF | grep wgpeer | wc -l)
my_suffix=$(($peers + 1))
base="$(echo $WG_NET | sed -Ee 's?^.*\.([^.]+)/.*$?\1?')"
base6="$(echo $WG_NET6 | sed -Ee 's/^.*:([^ /]+) .*$/\1/')"
my_base=$(($base + $my_suffix))
my_base6="$(printf '%x' $(($base6 + $my_suffix)))"

my_ip=$(echo $WG_NET | sed -E "s?^(.*\\.)([^.]+)(/.*)\$?\\1$my_base\\3?")
my_ip6=$(echo $WG_NET6 | sed -E "s?^(.*:)([^ /]+) (.*)\$?\\1$my_base6/\\3?")

echo "wgpeer $pubkey wgaip 0.0.0.0/0 wgaip ::/0 wgpsk $psk # user: $username" | doas tee -a /etc/hostname.$WG_IF >/dev/null
doas ifconfig $WG_IF wgpeer "$pubkey" wgaip 0.0.0.0/0 wgaip ::/0 wgpsk "$psk"

WWW_SECRET_ROOT=/var/www/$VPN_DOMAIN/$www_secret
doas mkdir -p $WWW_SECRET_ROOT
sed -e "s?{{privkey}}?$key?g;
s?{{my_ip}}?$my_ip?g;
s?{{my_ip6}}?$my_ip6?g;
s?{{host_ip}}?$MAIN_IP?g;
s?{{host_ip6}}?$MAIN_IP6?g;
s?{{hostpubkey}}?$WG_PUBKEY?g;
s?{{psk}}?$psk?g;
s?{{domain}}?$VPN_DOMAIN?g;
s?{{port}}?$WG_PORT?g;" $d/wgclient.template.conf | doas tee $WWW_SECRET_ROOT/wgclient.conf >/dev/null

doas qrencode -o $WWW_SECRET_ROOT/wgclient.png -t PNG <$WWW_SECRET_ROOT/wgclient.conf
doas cp $d/wg_index.html $WWW_SECRET_ROOT/index.html
doas chmod -R o-rwx $WWW_SECRET_ROOT

echo "${GREEN}VPN Configuration created!
${PURPLE}Download it at https://$VPN_DOMAIN/$www_secret/
or use the QR code below:"

qrencode -o - -t UTF8 "https://$VPN_DOMAIN/$www_secret/index.html"

echo -n "${NORM}"