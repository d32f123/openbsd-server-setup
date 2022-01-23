#!/bin/sh

ENVS="$(dirname $0)/../env.d"
. "$ENVS/general.sh"

echo "${YELLOW}Downloading VPN dependencies${NORM}"
doas pkg_add base64 libqrencode wireguard-tools ipcalc coreutils || panic "Failed to download dependencies"

SYSCTL_CONF=/etc/sysctl.conf
IKED_CONF=/etc/iked.conf
. "$ENVS/vpn.sh"

echo "${YELLOW}Configuring VPN on $MAIN_IF. IP: $MAIN_IP. IPv6: ${MAIN_IP6:-<none>}. VPN user: $VPN_USER${NORM}"

sysctlset() {
    option="$1"
    value="$2"

    doas sysctl "$option=$value"
    grep "^$option" $SYSCTL_CONF && \
	  doas sed -E -i.bak -e "s/^$option=[[:>:]]/$option=$value/" $SYSCTL_CONF || \
	   { 
		   echo "$option=$value # for VPN" | doas tee -a $SYSCTL_CONF >/dev/null ; 
	   }
}

sysctlset net.inet.ip.forwarding 1
sysctlset net.inet6.ip6.forwarding 1
sysctlset net.inet.esp.enable 1
sysctlset net.inet.esp.udpencap 1
sysctlset net.inet.ah.enable 1
sysctlset net.inet.ipcomp.enable 1

echo "${YELLOW}Configuring Unbound DNS server${NORM}"

UNBOUND_USER=_unbound
UNBOUND_GROUP=_unbound
UNBOUND_ROOT=/var/unbound
UNBOUND_ETC=$UNBOUND_ROOT/etc
UNBOUND_DB=$UNBOUND_ROOT/db
UNBOUND_CONF=$UNBOUND_ETC/unbound.conf

doas mkdir -p $UNBOUND_ETC $UNBOUND_DB

doas unbound-anchor
doas cp $UNBOUND_ETC/{unbound.conf,unbound.conf.bak}

BASE_VPN_NET=10.0.0.0/8
BASE_VPN_NET6=fc00:dead:beef::/48

IKEV2_VPN_IF=enc0

IKEV2_VPN_NET=10.1.0.0/16
IKEV2_VPN_ADDR=10.1.0.1
IKEV2_VPN_NTMSK=255.255.0.0
IKEV2_VPN_BRDCST=10.1.255.255

IKEV2_VPN_ADDR6=fc00:dead:beef:2000::1/52
IKEV2_VPN_NET6=fc00:dead:beef:2000::/52

WG_IF=wg0
WG_PORT=51820
WG_NET=10.2.0.1/16
WG_NET6="fc00:dead:beef:1000::1 52"

N_THREADS=$(doas sysctl | grep hw.ncpu= | cut -d= -f2)

{ [ -n "$MAIN_IP6" ] && cat || sed -e '/# IPv6/d;'; } <vpn/unbound.template.conf | \
	sed -e "s/{{n_threads}}/$N_THREADS/g;
s/{{main_if}}/$MAIN_IF/g;
s/{{main_ip}}/$MAIN_IP/g;
s?{{vpn_net}}?$BASE_VPN_NET?g;
s?{{main_ipv6}}?$MAIN_IP6?g;
s?{{vpn_net6}}?$BASE_VPN_NET6?g;" | doas tee $UNBOUND_CONF >/dev/null

echo "${YELLOW}Enabling and starting Unbound DNS server${NORM}"
doas chown $UNBOUND_USER:$UNBOUND_GROUP $UNBOUND_ROOT
doas rcctl enable unbound
doas rcctl restart unbound || panic "Failed to start Unbound with the new configuration"

prompt_bool "Set up IKEv2? It is less secure than WireGuard" "n" && {
	DO_IKEV2="yes"
	echo "${YELLOW}Configuring IKEv2 virtual interface $IKEV2_VPN_IF${NORM}"

	echo "inet $IKEV2_VPN_ADDR $IKEV2_VPN_NTMSK $IKEV2_VPN_BRDCST" | doas tee /etc/hostname.$IKEV2_VPN_IF >/dev/null
	[ -n "$MAIN_IP6" ] && { echo "inet6 $IKEV2_VPN_ADDR6" | doas tee -a /etc/hostname.$IKEV2_VPN_IF >/dev/null ; }
	echo "up" | doas tee -a /etc/hostname.$IKEV2_VPN_IF >/dev/null

	doas sh /etc/netstart

	prompt_password "Enter password for IKEv2 VPN:" password
	{ [ -n "$MAIN_IP6" ] && cat || sed -e '/# IPv6/,/# IPv6 end/d;'; } <vpn/iked.template.conf | \
	sed -e "s?{{ikev2_net6}}?$IKEV2_VPN_NET6?g;
s?{{ikev2_net}}?$IKEV2_VPN_NET?g;
s/{{main_if}}/$MAIN_IF/g;
s?{{password}}?$password?g;" | doas tee $IKED_CONF >/dev/null
	unset password
	doas chmod 600 $IKED_CONF

	echo "${YELLOW}Enabling and starting IKEd service${NORM}"
	doas rcctl enable iked
	doas rcctl restart iked || panic "Failed to start IKEd with the new configuration"
}

echo "${YELLOW}Configuring WireGuard VPN interface $WG_IF${NORM}"
echo "$WG_NET wgport $WG_PORT wgkey $(openssl rand -base64 32)" | doas tee /etc/hostname.$WG_IF >/dev/null
[ -n "$MAIN_IP6" ] && echo "inet6 $WG_NET6" | doas tee -a /etc/hostname.$WG_IF >/dev/null
doas chmod 600 /etc/hostname.$WG_IF

echo "${YELLOW}Restarting machine networking${NORM}"
doas sh /etc/netstart || panic "Failed to restart network services"
WG_PUBKEY="$(doas ifconfig $WG_IF | grep wgpubkey | cut -d' ' -f2)"

echo "${YELLOW}Configuring Packet Filter${NORM}"

{ [ -n "$DO_IKEV2" ] && cat || sed -e '/ikev2/d'; } <vpn/pf.template.conf | \
   { [ -n "$MAIN_IP6" ] && cat || sed -e '/ # IPv6/d'; } | \
   sed -e "s/{{ikev2_if}}/$IKEV2_VPN_IF/g;
s/{{wg_if}}/$WG_IF/g;
s/{{main_if}}/$MAIN_IF/g;" | doas tee -a /etc/pf.conf >/dev/null

echo "${YELLOW}Restarting Packet Filter${NORM}"
doas pfctl -f /etc/pf.conf || panic "Failed to start pf with the new configuration"

echo "${YELLOW}Creating a default user for WireGuard VPN${NORM}"
export MAIN_IF MAIN_IP MAIN_IP6 WG_IF WG_NET WG_NET6 WG_PUBKEY WG_PORT
vpn/wg_create_user.sh $USER_NAME

echo "${YELLOW}Creating an entry in /etc/daily.local to clear up VPN configurations available on https://$VPN_DOMAIN/ daily${NORM}"
echo "@daily ls -d /var/www/$VPN_DOMAIN/*/ | xargs rm -rf" | doas tee -a /etc/daily.local >/dev/null

echo "${PURPLE}${BOLD}You can create additional users for WireGuard by running ./vpn/wg_create_user.sh${NORM}"

# TODO: Set up OpenVPN instead of IKeV2
