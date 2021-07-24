.PHONY: rsync rsync-vm

rsync:
	rsync -avz ./ anesterov@anesterov.xyz:openbsd-server-setup/

rsync-vm:
	rsync -e 'ssh -p 2222' -avz ./ anesterov@172.16.82.2:openbsd-server-setup/
