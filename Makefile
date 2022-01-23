REMOTE=anesterov@anesterov.xyz
VM=testuser@testserver.test
LOCAL=$(shell ifconfig $$(route get 10.10.10.10 | sed -nE '/interface:/ { s/.*interface: +([^ ]+).*$$/\1/g; p; }') | \
	          sed -nE '/inet / { s/.*inet ([^ ]+).*$$/\1/; p; }')

.PHONY: rsync rsync-vm pebble

rsync:
	rsync -avz ./ $(REMOTE):openbsd-server-setup/

rsync-vm:
	rsync -avz ./ $(VM):openbsd-server-setup/
	ssh $(VM) sh -xvc \''cd openbsd-server-setup; sed -i.bak -e "/{{local}}/ s/{{local}}/$(LOCAL)/" setup.sh;'\'

ssh-vm:
	ssh $(VM) doas rdate pool.ntp.org
	ssh $(VM)

pebble:
	pebble -config test/pebble/pebble-config.json
