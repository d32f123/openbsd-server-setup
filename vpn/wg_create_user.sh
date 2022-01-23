#!/bin/sh
# Creates a new WireGuard VPN client
# Usage: wg_create_user.sh <username>
# Script will spew out a QR Code and a link to the WireGuard configuration.
# The link will be invalidated at midnight by a cronjob which is set up during 007_vpn.sh
usage="Usage: wg_create_user.sh <username>"

d="$(dirname $0)"
ENVS="$d/../env.d"
. "$ENVS/general.sh"

username="$1"
[ -z "$username" ] && panic "$usage"

. "$ENVS/vpn.sh"

echo "${YELLOW}Creating user $username for $VPN_DOMAIN${NORM}"

www_secret="$(openssl rand -base64 32 | ghead -c 20)"
key="$(wg genkey)"
psk="$(wg genpsk)"
pubkey="$(echo $key | wg pubkey)"

peers=$(doas wg show $WG_IF peers | wc -l)
my_suffix=$(($peers + 1))
base="$(echo $WG_NET | sed -Ee 's?^.*\.([^.]+)/.*$?\1?')"
base6="$(echo $WG_NET6 | sed -Ee 's/^.*:([^ /]+) .*$/\1/')"
my_base=$(($base + $my_suffix))
my_base6="$(printf '%x' $(($base6 + $my_suffix)))"

my_ip=$(echo $WG_NET | sed -E "s?^(.*\\.)([^.]+)/.*\$?\\1$my_base/32?")
my_ip6=$(echo $WG_NET6 | sed -E "s?^(.*:)([^ /]+) .*\$?\\1$my_base6/128?")

IFCONFIG_WGAIPS="wgaip $my_ip"
[ -n "$MAIN_IP6" ] && IFCONFIG_WGAIPS="$IFCONFIG_WGAIPS wgaip $my_ip6"
echo "wgpeer $pubkey $IFCONFIG_WGAIPS wgpsk $psk # user: $username" | doas tee -a /etc/hostname.$WG_IF >/dev/null
doas ifconfig $WG_IF wgpeer "$pubkey" $IFCONFIG_WGAIPS wgpsk "$psk"

WWW_SECRET_ROOT=/var/www/$VPN_DOMAIN/$www_secret
doas mkdir -p $WWW_SECRET_ROOT
{ [ -n "$MAIN_IP6" ] && cat || sed -e '/ # IPv6/ s/^.*$//;'; } <$d/wgclient.template.conf | \
    sed -e "s?{{privkey}}?$key?g;
s?{{my_ip}}?$my_ip?g;
s?{{host_ip}}?$MAIN_IP?g;
s?{{hostpubkey}}?$WG_PUBKEY?g;
s?{{psk}}?$psk?g;
s?{{domain}}?$VPN_DOMAIN?g;
s?{{port}}?$WG_PORT?g;
s?{{my_ip6}}?$my_ip6?g;
s?{{host_ip6}}?$MAIN_IP6?g;
s/ # IPv6.*$//g;" | sed -e '/<NEWLINE>$/ {s/<NEWLINE>//; N; s/\n/ /; }' | doas tee $WWW_SECRET_ROOT/wgclient.conf >/dev/null

doas cat $WWW_SECRET_ROOT/wgclient.conf | doas qrencode -o $WWW_SECRET_ROOT/wgclient.png -t PNG
doas cp $d/wg_index.html $WWW_SECRET_ROOT/index.html
doas chmod -R o-rwx $WWW_SECRET_ROOT

echo "${GREEN}VPN Configuration created!
${PURPLE}Download it at https://$VPN_DOMAIN/$www_secret/
or use the QR code below:"

qrencode -o - -t UTF8 "https://$VPN_DOMAIN/$www_secret/index.html"

echo -n "${NORM}"