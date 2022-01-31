# Development

## Workbench setup

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
4. Run `make rsync`. This will send this whole directory to the VM and do a replace in [setup.sh](./setup.sh) that allows the VM to target the Host when requesting SSL certificates via Certbot.
5. Spin up Pebble (stub certificate server) by running `make pebble` on the Host machine. See [test/pebble/](./test/pebble) for more info.
6. SSH into the VM and run the script. You might want to test the stages one by one by running `./setup.sh <stage>`. **Note:** when running stage SSL, be sure to pass `--ssl-test` flag to target local Pebble server.

**Note!** If you are using snapshots, the time will go terribly wrong on the VM. To fix it: `rdate pool.ntp.org`  
Use `make ssh` to do `rdate` and ssh to the VM in one go (requires `doas` already being set up)

## Repo structure

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