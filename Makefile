.PHONY: help build clean

help:
	@echo "Targets:"
	@echo "  build  - build gatus + os-gatus packages (FreeBSD only)"
	@echo "  clean  - remove generated build artifacts"

build:
	@./scripts/build-packages.sh

clean:
	rm -rf artifacts net-mgmt/gatus/work ports/www/gatus/work
