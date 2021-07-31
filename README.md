# Instructions and files to set up a functional OpenBSD server

## Stack
* Shell: zsh, oh-my-zsh, tmux
* SSH
* Web server – nginx with automatic http to https redirect and A+ SSL
* Mail server – OpenSMTPD, Dovecot, Rspamd, RainLoop

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

## Script parameters

`USER_NAME` – the user which will be used for everything in the script. Defaults to current user.
`DOMAIN_NAME` – the domain name to create websites for. Defaults to `$(hostname | cut -d. -f2-)`

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

Optional, manual: set up a reverseDNS record at your VPS provider

Required if using VPS: port 25 is required to receive mail. 
If you're using VPS chances are it is blocked by default.
You will have to contact your VPS provider to open port 25.

### Stage 6 – fail2ban setup