.PHONY: rsync
rsync:
	rsync -e 'ssh -p 2222' -avz ./ anesterov@172.16.82.2:openbsd-server-setup/
