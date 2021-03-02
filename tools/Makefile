EUID    := $(shell id -u -r)

purge: purge.c
ifneq ($(EUID),0)
	@echo "Root or sudo is required" >&2
	@exit 1
endif
	gcc purge.c -o purge
	chown root:root purge
	chmod 6711 purge
