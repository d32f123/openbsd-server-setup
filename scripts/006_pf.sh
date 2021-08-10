#!/bin/sh

ssh_port=$(grep -q -E "^Port [^#]+" /etc/ssh/sshd_config && sed -nE 's/^Port ([^#]+)/\1/p' /etc/ssh/sshd_config || echo ssh)

echo "Protecting ssh ($ssh_port) from brute force attacks
Protecting mail auth (submission) from brute force attacks
Protecting imap (imaps) from brute force attacks
Protecting HTTP and HTTPS (80, 443) from brute force attacks
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
        (max-src-conn 5, max-src-conn-rate 15/3, \\
        overload <bruteforce> flush global)

pass proto tcp from any to any port { www https } \\
        flags S/SA keep state \\
        (max-src-conn 20, max-src-conn-rate 40/3, \\
        overload <bruteforce> flush global)
"

PF_CONF=/etc/pf.conf
echo "$pf_conf" | doas tee -a $PF_CONF

doas rcctl enable pf

echo "Creating a cron job to clear old bans daily"
CRONJOB="@daily pfctl -t bruteforce -T expire 86400"
{ doas crontab -l 2>/dev/null ; echo "$CRONJOB" ; } | doas crontab -
