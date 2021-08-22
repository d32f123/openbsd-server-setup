#!/bin/sh

SYSCTL_CONF=/etc/sysctl.conf
IKED_CONF=/etc/iked.conf

MAIN_IF="$(ls /etc/hostname.* | grep -v enc | grep -v wg | head -1 | cut -d. -f 2)"
MAIN_IP="$(ifconfig $MAIN_IF | grep inet | grep -v inet6 | cut -d' ' -f2)"
MAIN_IP6="$(ifconfig $MAIN_IF | grep inet6 | grep -v '%' | cut -d' ' -f2)"

VPN_USER=vpn

echo "${YELLOW}Configuring VPN on $MAIN_IF. IP: $MAIN_IP. IPv6: $MAIN_IP6. VPN user: $VPN_USER${NORM}"

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
sed -e "s/{{n_threads}}/$N_THREADS/g;
s/{{main_if}}/$MAIN_IF/g;
s/{{main_ip}}/$MAIN_IP/g;
s?{{main_ipv6}}?$MAIN_IP6?g;
s?{{vpn_net}}?$BASE_VPN_NET?g;
s?{{vpn_net6}}?$BASE_VPN_NET6?g;" vpn/unbound.template.conf | doas tee $UNBOUND_CONF >/dev/null

echo "${YELLOW}Enabling and starting Unbound DNS server${NORM}"
doas chown $UNBOUND_USER:$UNBOUND_GROUP $UNBOUND_ROOT
doas rcctl enable unbound
doas rcctl restart unbound || {
	echo "${RED}Failed to start Unbound with the new configuration${NORM}"
	exit 1
}

if [ -n "$DO_IKEV2" ]; then
	echo "${YELLOW}Configuring IKEv2 virtual interface $IKEV2_VPN_IF${NORM}"

	echo "inet $IKEV2_VPN_ADDR $IKEV2_VPN_NTMSK $IKEV2_VPN_BRDCST
inet6 $IKEV2_VPN_ADDR6
up" | doas tee /etc/hostname.$IKEV2_VPN_IF >/dev/null
	doas sh /etc/netstart

	echo "${PURPLE}Enter password for IKEv2 VPN: ${NORM}\c" >/dev/tty ; stty -echo ; read password ; stty echo ; echo >/dev/tty ; 
	sed -e "s?{{ikev2_net6}}?$IKEV2_VPN_NET6/g;
s?{{ikev2_net}}?$IKEV2_VPN_NET?g;
s/{{main_if}}/$MAIN_IF/g;
s?{{password}}?$password?g;" vpn/iked.template.conf | doas tee $IKED_CONF >/dev/null
	unset password
	doas chmod 600 $IKED_CONF

	echo "${YELLOW}Enabling and starting IKEd service${NORM}"
	doas rcctl enable iked
	doas rcctl restart iked || {
		echo "${RED}Failed to start IKEd with the new configuration${NORM}"
		exit 1
	}
fi

echo "${YELLOW}Configuring WireGuard VPN interface $WG_IF${NORM}"
echo "$WG_NET wgport $WG_PORT wgkey $(openssl rand -base64 32)
inet6 $WG_NET6" | doas tee /etc/hostname.$WG_IF >/dev/null
doas chmod 600 /etc/hostname.$WG_IF

echo "${YELLOW}Restarting machine networking${NORM}"
doas sh /etc/netstart || {
	echo "${RED}Failed to restart network services${NORM}"
	exit 1
}
WG_PUBKEY="$(doas ifconfig $WG_IF | grep wgpubkey | cut -d' ' -f2)"

echo "${YELLOW}Configuring Packet Filter${NORM}"

{ 
	[ -n "$DO_IKEV2" ] && cat || sed -e '/ikev2/d' 
} <vpn/pf.template.conf | sed -e "s/{{ikev2_if}}/$IKEV2_VPN_IF/g;
s/{{wg_if}}/$WG_IF/g;
s/{{main_if}}/$MAIN_IF/g;" | doas tee -a /etc/pf.conf >/dev/null

echo "${YELLOW}Restarting Packet Filter${NORM}"
doas pfctl -f /etc/pf.conf || {
	echo "${RED}Failed to start pf with the new configuration${NORM}"
	exit 1
}

echo "${YELLOW}Creating a default user for WireGuard VPN${NORM}"
export MAIN_IF MAIN_IP MAIN_IP6 WG_IF WG_NET WG_NET6 WG_PUBKEY WG_PORT
vpn/wg_create_user.sh $USER_NAME

echo "${YELLOW}Creating a cron job to clear up VPN configurations available on https://$VPN_DOMAIN/ daily${NORM}"
CRONJOB="@daily ls -d /var/www/$VPN_DOMAIN/*/ | xargs rm -rf"
{ doas crontab -l 2>/dev/null ; echo "$CRONJOB" ; } | doas crontab -

echo "${PURPLE}${BOLD}You can create additional users for WireGuard by running ./vpn/wg_create_user.sh${NORM}"

# TODO: Set up OpenVPN instead of IKeV2
