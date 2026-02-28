.PHONY: help build clean release-show release-tag bump-gatus-revision bump-plugin-revision

help:
	@echo "Targets:"
	@echo "  build  - build gatus + os-gatus packages (FreeBSD only)"
	@echo "  clean  - remove generated build artifacts"
	@echo "  release-show          - show current package versions and computed release tag"
	@echo "  release-tag           - print computed release tag only"
	@echo "  bump-gatus-revision   - increment gatus PORTREVISION"
	@echo "  bump-plugin-revision  - increment os-gatus PLUGIN_REVISION"

build:
	@./scripts/build-packages.sh

clean:
	rm -rf artifacts net-mgmt/gatus/work ports/www/gatus/work

release-show:
	@./scripts/release.sh show

release-tag:
	@./scripts/release.sh tag

bump-gatus-revision:
	@./scripts/release.sh bump-gatus-revision

bump-plugin-revision:
	@./scripts/release.sh bump-plugin-revision
