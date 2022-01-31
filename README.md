# Instructions and files to set up a functional OpenBSD server

This collection of scripts will set up a Web server with SSL certificates, Mail server with anti-spoofing measures, and a VPN.  
Pure shell scripts + config files, no unneeded dependencies.

**Note:** IPv4 only and IPv4+IPv6 setups are supported. 
IPv6 only **WILL NOT** work. You can still use this repo as a reference though.

## Stack
* Shell: zsh, oh-my-zsh, tmux
* SSH
* Web server – nginx with automatic http to https redirect and A+ SSL
* Mail server – OpenSMTPD, Dovecot, Rspamd, Redis, RainLoop (optional, pulls PHP)
* Brute force protection: PF
* VPN: WireGuard, OpenIKED (optional), Unbound, PF

## Prerequisites
If you want to enable *IPv6*, then add this line to your /etc/hostname.*:
```
inet6 autoconf -temporary -soii
```

You will have to set up some DNS records prior to running this script.  
Create the following DNS records:
```
;; Host       TTL Type  Value
*.{domain}.	  300	IN	A	{ip}
{domain}.	    300	IN	A	{ip}
www.{domain}. 300	IN	A	{ip}

;; Only for IPv6:
*.{domain}.   300 IN  AAAA {ipv6}
{domain}.     300 IN  AAAA {ipv6}
www.{domain}. 300 IN  AAAA {ipv6}
```

Use `ifconfig` to get your IP address or consult your VPS provider.

**Note:** If you cannot use wildcard (*.{domain}.) record, 
set up these domains explicitly instead:  
`vpn.{domain}, mail.{domain}, www.vpn.{domain}, www.mail.{domain}, www.{domain}, {domain}`

## Usage

1. Get a VPS or a physical host with OpenBSD
2. Do the prerequisites (see above)
3. Create a user for yourself and login
4. `git clone https://github.com/d32f123/openbsd-server-setup` // TODO: Repalce with wget
5. `cd openbsd-server-setup; ./setup.sh`
6. Follow the script's instructions
7. Do any post-install actions (see generated `post-install.txt`)

## Running
```sh
./setup.sh [bootstrap] [shell] [nginx] [ssl [--ssl-test]] [mail] [pf] [vpn] 
```
* When no options given, runs all stages sequentially
* `--ssl-test` flag is used for [local development](./docs/development.md)
* Before running the script, be sure to check the stages below and decide what you need.  
* All relevant post-install information will be available at `post-install.txt` 
  after the script completes, so don't be afraid if you lose some of the script's output.

## Script stages

**Stages and their package dependencies are located in [./scripts/](scripts/) directory**.  
Look for the `doas pkg_add ...` line in the beginning of the corresponding script.

### Stage 1 – [bootstrap]

**Skip it if `doas` is already set up**

Bootstrap does some basic configuration.  
Currently it enables main user to do `doas` and enables slaacd for IPv6.

### Stage 2 – [shell] setup

Sets up an opinionated zsh+tmux environment.  
Completely optional.

### Stage 3 – [nginx] setup

Depends on: **doas**  
Dependants: **ssl, mail, vpn**

1. Creates nginx configuration and logs directories
2. Creates configs and dirs for sites domain.xxx, mail.domain.xxx, vpn.domain.xxx.  
   If you are not planning to use mail or vpn, you might want to remove some of these configs.

Websites are located under /var/www/  
Configuration is located at /etc/nginx/

### Stage 4 – [ssl] setup

Depends on: **doas, nginx**  
Dependants: **mail**

1. Gets certificates via certbot
2. Switches nginx configuration to use only secure versions of domains

The certificates obtained here are also used to serve Mail frontend and VPN configurations.

### Stage 5 – [mail] server setup

Depends on: **doas, nginx, ssl**

1. Sets up smtpd (main mail server), dovecot (IMAP server), rspamd (mail signing)
2. Creates a user account username@domainname
3. There are scripts available to add and delete users, change passwords
4. Makes local mail (sent by `$ mail ...` to local users) available over IMAP
5. Requires post-install procedures (see below)
6. (optional) sets up RainLoop web frontend. Available at mail.{{domain_name}}

**Additional post-install**

**Required**:
This stage will spew out some additional DNS records, which confirm that
mail is indeed coming from your domain name (spoofing protection).

Optional: set up a reverseDNS record at your VPS provider

**Note to VPS users**: port 25 is required to receive mail. 
If you're using VPS chances are it is blocked by default.
You will have to contact your VPS provider to open port 25.

### Stage 6 – [pf] Packet Filter setup

Sets up packet filter to block ips which spam your SSH, HTTP, HTTPS, IMAP, SMTP ports

### Stage 7 – [vpn] setup

Depends on: **doas, nginx**

Sets up WireGuard VPN and optionally OpenIKED IKEv2.
Spins up a local Unbound DNS server for better privacy.

VPN configurations for new clients can be created via a script (WireGuard only).  
Configurations are made available at a random endpoint at vpn.{{domain}}/  
QRs are provided to simplify importing configs to mobile clients.

WireGuard uses asymmetric key + Preshared Key authentication. IKEv2 uses Preshared key authentication.

## Script parameters
You can override the following envvars prior to running the script to modify it's behavior:
- `USER_NAME` – the user which will be used for everything in the script. Defaults to current user.
- `DOMAIN_NAME` – the domain name to create websites for. Defaults to `$(hostname | cut -d. -f2-)`
- `MAIL_DOMAIN` – the domain name where mail server will be hosted. Defaults to `mail.$DOMAIN_NAME`
- `VPN_DOMAIN` – the domain name where VPNs will be hosted (including their configurations). Defaults to `vpn.$DOMAIN_NAME`

## Feedback

Feel free to provide feedback and imrpovemend ideas / report any issues here on GitHub (issues or pull requests)  
or mail me at <anesterov@anesterov.xyz>. I will be grateful for any kind of feedback!

## Future ideas
- Add OpenVPN support
- Add a prompt to create a cron that rotates DKIM keys  
  (will require manual rotation at the DNS provider side 
  (may be possible to automate for certain providersvia API))
- Consider migrating from nginx to built-in httpd

## [Development (see development.md)](./docs/development.md)

## [Acknowledgements (see acknowledgements.md)](./docs/acknowledgements.md)