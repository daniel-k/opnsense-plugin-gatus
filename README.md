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
- ABI marker (`artifacts/ABI`)

## Install manually on OPNsense (one-off)

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

GitHub Actions does two things:

1. builds both packages on FreeBSD and uploads them as an artifact
2. publishes a FreeBSD pkg repository to GitHub Pages

The FreeBSD build job also uses a GitHub Actions cache for:

- `/usr/ports/distfiles` (source tarballs/patches fetched by ports)
- `/var/cache/pkg` (`pkg` download cache)

This reduces repeated network downloads on later runs. A new cache is populated
automatically after a cache miss.

### Refreshing the CI cache (important)

Cache key version is defined in `.github/workflows/build.yml` as:
`freebsd-14_3-downloads-v1-...`

To force a fresh cache generation, bump the `v1` part (for example to `v2`),
commit, and push. The first run after the bump is expected to be slower (cold
cache). The next runs should be faster again.

When to refresh on purpose:

- after changing FreeBSD release in CI (for example `14.3` -> `14.4`)
- after major dependency/toolchain shifts that change many downloads
- when cache content appears stale/corrupt (unexpected fetch/checksum failures
  that disappear after retry)
- when download behavior regresses and logs show too many cache misses

Published layout:

- `https://<owner>.github.io/<repo>/<ABI>/...`
- example ABI path for this build: `FreeBSD:14:amd64`

To enable publishing, set repository Pages source to **GitHub Actions**.

## Integrate the repo in OPNsense (automatic updates)

Create a pkg repository file on the firewall:

```sh
cat >/usr/local/etc/pkg/repos/gatus.conf <<'EOF'
gatus: {
  url: "pkg+https://<owner>.github.io/<repo>/${ABI}",
  mirror_type: "none",
  signature_type: "none",
  enabled: yes
}
EOF
pkg update -f
```

Then install from the repo:

```sh
pkg install os-gatus
```

After this, `os-gatus` and `gatus` are eligible for normal update flows (`pkg upgrade` and OPNsense firmware/plugin updates).

Important: updates are only offered when package versions increase (`DISTVERSION`, `PLUGIN_VERSION`, or `PLUGIN_REVISION`).
