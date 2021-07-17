# Instructions and files to set up a functional OpenBSD server

## Stack
* Shell: zsh, oh-my-zsh, tmux
* SSH
* Web server – nginx with automatic http to https redirect and A+ SSL
* Mail server – OpenSMTPD, Dovecot, Rspamd, RainLoop

## Shell setup

After installing OpenBSD, first steps should be to get a usable shell

```shell
# setup doas
echo "permit nopass anesterov as root" > /etc/doas.conf
pkg_add vim
```

## SSH Connection
Let's now set up an ssh server so that we will be able to ssh into it.

