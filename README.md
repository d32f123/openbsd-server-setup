# Instructions and files to set up a functional OpenBSD server

## Stack
* Shell: zsh, oh-my-zsh, tmux
* SSH
* Web server – nginx with automatic http to https redirect and A+ SSL
* Mail server – OpenSMTPD, Dovecot, Rspamd, RainLoop

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
3. Gets certificates via certbot
4. Switches nginx configuration to use only secure versions of domains

