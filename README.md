# opnsense-gatus

Builds two packages for OPNsense amd64:

- `gatus` (FreeBSD port package)
- `os-gatus` (OPNsense plugin with web UI)

The plugin provides a `Services -> Gatus` page where you can:

- enable/disable the service
- tune runtime options (user, log level, startup delay)
- edit the full `gatus.yaml` file from the UI

## Repository layout

- `ports/www/gatus`: FreeBSD port for `gatus`
- `net-mgmt/gatus`: OPNsense plugin sources (`os-gatus`)
- `Mk`, `Templates`, `Scripts`, `Keywords`: OPNsense plugin build tooling

## Build locally (FreeBSD)

```sh
./scripts/build-packages.sh
```

Prerequisite: FreeBSD ports tree available at `/usr/ports` (for example:
`git clone --depth 1 https://git.FreeBSD.org/ports.git /usr/ports`).

Artifacts end up in `artifacts/All/`:

- `gatus-<version>.pkg`
- `os-gatus-<version>.pkg`
- repository metadata (`packagesite.pkg`, `meta.conf`, ...)

## Install on OPNsense

1. Copy/download both packages to the firewall.
2. Install dependency first:
   ```sh
   pkg add ./gatus-<version>.pkg
   ```
3. Install plugin:
   ```sh
   pkg add ./os-gatus-<version>.pkg
   ```
4. Open `Services -> Gatus` in the web UI and configure/save.

## CI

GitHub Actions builds both packages on FreeBSD and uploads `artifacts/All`.
