# Instructions and files to set up a functional OpenBSD server

## Stack
* Shell: zsh, oh-my-zsh, tmux
* SSH
* Web server – nginx with automatic http to https redirect and A+ SSL
* Mail server – OpenSMTPD, Dovecot, Rspamd, Redis, RainLoop (+PHP, optional)
* Brute force protection: PF
* VPN: OpenIKED, WireGuard, Unbound, PF

## Prerequisites
You will have to set up some DNS records prior to running this script.
Create the following DNS records:
```
*.{domain}.	300	IN	A	{ip}
{domain}.	300	IN	A	{ip}
www.{domain}	300	IN	A	{ip}

;; DNS records for mail (will be output after stage 5)
{domain}.	300	IN	MX	0 mail.{domain}. ;; so that people know which server serves mail for {domain}
@      IN TXT  "v=spf1 mx a:mail.{domain} -all"
```

Instead of using wildcard (*.{domain}.) you can just set up these domains explicitly:
vpn.{domain}, mail.{domain}, www.vpn.{domain}, www.mail.{domain}, www.{domain}, {domain}

If you want to enable *IPv6*, then add this line to your /etc/hostname.*:
```
inet6 autoconf -autoconfprivacy -soii
```

## Running
```shell
./setup.sh [stage]
```

## Script parameters

`USER_NAME` – the user which will be used for everything in the script. Defaults to current user.
`DOMAIN_NAME` – the domain name to create websites for. Defaults to `$(hostname | cut -d. -f2-)`
`MAIL_DOMAIN` – the domain name where mail server will be hosted. Defaults to `mail.$DOMAIN_NAME`
`VPN_DOMAIN` – the domain name where VPNs will be hosted (including their configurations). Defaults to `vpn.$DOMAIN_NAME`

## Script stages

### Stage 1 – bootstrap

Bootstrap stage enables main user to do `doas` and downloads all needed dependencies

### Stage 2 – shell setup

Sets up zsh, tmux

### Stage 3 – nginx setup

1. Creates nginx configuration and logs directories.
2. Creates nginx configurations for domain.xxx and mail.domain.xxx

### Stage 4 – nginx SSL setup

1. Gets certificates via certbot
2. Switches nginx configuration to use only secure versions of domains

### Stage 5 – mail server setup

1. Sets up smtpd, dovecot, rspamd, redis
2. Creates a user account username@domainname
3. There are scripts available to add, change password and to delete users
4. Prints DNS records that you should set up
5. Local mail is forwarded to vmail directories (to be able to fetch them via IMAP)

Optional: set up RainLoop web frontend

Optional, manual: set up a reverseDNS record at your VPS provider

Required if using VPS: port 25 is required to receive mail. 
If you're using VPS chances are it is blocked by default.
You will have to contact your VPS provider to open port 25.

### Stage 6 – PF (packet filter) setup

Sets up packet filter to block ips which spam your SSH, HTTP, HTTPS, IMAP, SMTP ports

### Stage 7 – VPN setup

Sets up OpenIKED IKEv2 and WireGuard VPN.
Ideas taken from EdgeWalker script https://github.com/fazalmajid/edgewalker

By default, IKEv2 configuration is not set up.
IKEv2 uses Preshared key authentication. WireGuard uses asymmetric key + Preshared Key authentication.

New VPN configurations for new clients can be created via a script (WireGuard only).
Configurations are made available at a random endpoint at vpn.{{domain}}/

