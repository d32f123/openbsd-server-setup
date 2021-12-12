#!/bin/sh

ssh_port=$(grep -q -E "^Port [^#]+" /etc/ssh/sshd_config && sed -nE 's/^Port ([^#]+)/\1/p' /etc/ssh/sshd_config || echo ssh)

echo "${YELLOW}Protecting ssh ($ssh_port) from brute force attacks
Protecting mail auth (submission) from brute force attacks
Protecting imap (imaps) from brute force attacks
Protecting HTTP and HTTPS (80, 443) from brute force attacks${NORM}
"

pf_conf="
table <bruteforce> persist
block quick from <bruteforce>

pass proto tcp from any to any port $ssh_port \\
        flags S/SA keep state \\
        (max-src-conn 15, max-src-conn-rate 5/3, \\
        overload <bruteforce> flush global)

pass proto tcp from any to any port { submission imaps } \\
        flags S/SA keep state \\
        (max-src-conn 30, max-src-conn-rate 100/3, \\
        overload <bruteforce> flush global)

pass proto tcp from any to any port { www https } \\
        flags S/SA keep state \\
        (max-src-conn 100, max-src-conn-rate 100/1, \\
        overload <bruteforce> flush global)
"

PF_CONF=/etc/pf.conf
echo "$pf_conf" | doas tee -a $PF_CONF >/dev/null

doas rcctl enable pf

echo "${YELLOW}Creating a cron job to clear old bans daily${NORM}"
CRONJOB="@daily pfctl -t bruteforce -T expire 86400"
{ doas crontab -l 2>/dev/null ; echo "$CRONJOB" ; } | doas crontab -
