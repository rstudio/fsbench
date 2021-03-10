EUID    := $(shell id -u -r)

purge-disk-cache: purge-disk-cache.c
	gcc purge-disk-cache.c -o purge-disk-cache

install: purge-disk-cache
ifneq ($(EUID),0)
	@echo "Root or sudo is required" >&2
	@exit 1
endif
	mkdir -p /usr/local/sbin/
	cp purge-disk-cache /usr/local/sbin/
	chown root /usr/local/sbin/purge-disk-cache
	chmod 6711 /usr/local/sbin/purge-disk-cache
