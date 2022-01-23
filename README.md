# Instructions and files to set up a functional OpenBSD server

**Note:** IPv4 only and IPv4+IPv6 setups are supported. 
IPv6 only **WILL NOT** work. You can still use this repo as a reference though.

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
inet6 autoconf -temporary -soii
```

## Running
```sh
./setup.sh [stage] [--ssl-test]
# Stages: bootstrap shell nginx ssl mail pf vpn
# By default runs all stages
# --ssl-test flag is used for local development (see `Local Development` section)
```

## Script stages

**Stages and their dependencies are located in [scripts/](scripts/) directory**. For dependencies, look for the `doas pkg_add ...` line in the beginning of the corresponding script.

### Stage 1 – **bootstrap**

**Skip it if `doas` is already set up**

Bootstrap does some basic configuration.  
Currently it enables main user to do `doas` and enables slaacd for IPv6.

### Stage 2 – **shell** setup

Sets up zsh, tmux.  
Completely optional.

### Stage 3 – **nginx** setup

Depends on: **doas**
Dependants: **ssl, mail, vpn**

1. Creates nginx configuration and logs directories.
2. Creates nginx configurations for domain.xxx and mail.domain.xxx

### Stage 4 – nginx **ssl** setup

Depends on: **doas, nginx**
Dependants: **mail**

1. Gets certificates via certbot
2. Switches nginx configuration to use only secure versions of domains

### Stage 5 – **mail** server setup

Depends on: **doas, nginx, ssl**

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

### Stage 6 – **pf** Packet Filter setup

Sets up packet filter to block ips which spam your SSH, HTTP, HTTPS, IMAP, SMTP ports

### Stage 7 – **vpn** setup

Depends on: **doas, nginx**

Sets up OpenIKED IKEv2 and WireGuard VPN.
Ideas taken from EdgeWalker script https://github.com/fazalmajid/edgewalker

By default, IKEv2 configuration is not set up.
IKEv2 uses Preshared key authentication. WireGuard uses asymmetric key + Preshared Key authentication.

New VPN configurations for new clients can be created via a script (WireGuard only).
Configurations are made available at a random endpoint at vpn.{{domain}}/

## Script parameters

* `USER_NAME` – the user which will be used for everything in the script. Defaults to current user.
* `DOMAIN_NAME` – the domain name to create websites for. Defaults to `$(hostname | cut -d. -f2-)`
* `MAIL_DOMAIN` – the domain name where mail server will be hosted. Defaults to `mail.$DOMAIN_NAME`
* `VPN_DOMAIN` – the domain name where VPNs will be hosted (including their configurations). Defaults to `vpn.$DOMAIN_NAME`

## Development

### Workbench setup

Virtualization software like VMWare Fusion can help with testing the scripts. To do local development against a vm, do the following setup.

1. Download and install the virtualization software of choice, an OpenBSD .iso and do a basic installation of OpenBSD on the VM.
When installing, create a user `testuser`.
2. Once inside the VM, do the following initial setup:
    1. Configure networking so that the VM can communicate both with the Host and the outside world. In VMWare Fusion, this is done by selecting `Bridged Networking` option. Be sure to set a static IP for your VM inside of your network for easier maintanence (e.g set `/etc/hostname.em0` to `inet 192.168.0.111 255.255.255.0 192.168.0.255`). 
    2. Edit `/etc/myname`, set it to `testserver.testserver.test`
    3. Edit `/etc/mygate`, set it to your network's default gateway (usually `192.168.0.101`)
    4. Edit `/etc/hosts`, add the following entry:
        ```
        {{VM Static IP}} testserver.test mail.testserver.test vpn.testserver.test www.testserver.test www.mail.testserver.test www.vpn.testserver.test
        ```
    5. Edit `/etc/resolv.conf`:
       ```
       nameserver <network's gate from step 3>
       lookup file bind
       ```
    6. Enable sshd and set up a connection to testuser.
    7. `pkg_add rsync`.
    8. Reboot the VM for good measure.
3. Add the same entry to `/etc/hosts` on the Host as in (2.4)
4. Run `make rsync-vm`. This will send this whole directory to the VM and do a replace in [setup.sh](./setup.sh) that allows the VM to target the Host when requesting SSL certificates via Certbot.
5. Spin up Pebble (stub certificate server) by running `make pebble` on the Host machine. See [test/pebble/](./test/pebble) for more info.
6. SSH into the VM and run the script. You might want to test the stages one by one by running `./setup.sh <stage>`. **Note:** when running stage SSL, be sure to pass `--ssl-test` flag to target local Pebble server.

**Note!** If you are using snapshots, the time will go terribly wrong on the VM. To fix it: `rdate pool.ntp.org`  
Use `make ssh-vm` to do `rdate` and ssh to the VM in one go (requires `doas`)

### Repo structure

- README.md – usage instructions, general information about the scripts
- Makefile – contains targets that ease development
- setup.sh – main file that launches the scripts corresponding to particular Stages (see Stages section)
- scripts/ – contains scripts for particular stages.
- env.d/ – contains environment variables and aux functions used by different scripts.
- mail/ - contains configuration templates for dovecot, smtpd et c. Also contains scripts that allow creating new users, deleting existing users and changing passwords.
- nginx/ – contains configuration templates for nginx and site templates
- vpn/ – contains configuration templates for IKEd, WireGuard.
- vpn/wg_create_user.sh – creates additional WireGuard users
- test/ - contains configuration files needed for local development and testing
