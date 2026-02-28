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

GitHub Actions is split into two workflows:

1. `.github/workflows/build.yml` (push/PR/manual): builds both packages on
   FreeBSD and uploads them as an artifact (no publishing)
2. `.github/workflows/release.yml` (GitHub release `published`): rebuilds both
   packages and publishes the pkg repository to GitHub Pages

Only explicit GitHub releases publish to Pages.

Both workflows use a GitHub Actions cache for:

- `/usr/ports/distfiles` (source tarballs/patches fetched by ports)
- `/var/cache/pkg` (`pkg` download cache)

This reduces repeated network downloads on later runs. A new cache is populated
automatically after a cache miss.

### Refreshing the CI cache (important)

Cache key version is defined in both `.github/workflows/build.yml` and
`.github/workflows/release.yml` as:
`freebsd-14_3-downloads-v1-...`

To force a fresh cache generation, bump the `v1` part (for example to `v2`),
commit, and push (keep both workflow files in sync). The first run after the
bump is expected to be slower (cold cache). The next runs should be faster
again.

When to refresh on purpose:

- after changing FreeBSD release in CI (for example `14.3` -> `14.4`)
- after major dependency/toolchain shifts that change many downloads
- when cache content appears stale/corrupt (unexpected fetch/checksum failures
  that disappear after retry)
- when download behavior regresses and logs show too many cache misses

### Release tag format

Releases must use this exact tag format:

`rel/gatus-v<GATUS_PKGVER>+os-gatus-v<PLUGIN_PKGVER>`

Where:

- `GATUS_PKGVER` = `DISTVERSION` + `_PORTREVISION` when `PORTREVISION > 0`
- `PLUGIN_PKGVER` = `PLUGIN_VERSION` + `_PLUGIN_REVISION` when
  `PLUGIN_REVISION > 0`

Example:

`rel/gatus-v5.35.0+os-gatus-v1.0_1`

The release workflow validates that the release tag matches the versions in the
repository at the tagged commit.

### Release helper tooling

Use `scripts/release.sh` to inspect versions, bump revisions, and create tags /
GitHub releases.

Show current versions and computed tag:

```sh
./scripts/release.sh show
```

Print only the computed tag:

```sh
./scripts/release.sh tag
```

Set explicit versions:

```sh
# Set upstream gatus version and reset PORTREVISION to 0
./scripts/release.sh set-gatus 5.36.0

# Set upstream gatus version + explicit PORTREVISION
./scripts/release.sh set-gatus 5.36.0 1

# Set plugin version + optional revision (default revision: 0)
./scripts/release.sh set-plugin 1.1
./scripts/release.sh set-plugin 1.1 2
```

Bump only packaging revisions:

```sh
./scripts/release.sh bump-gatus-revision
./scripts/release.sh bump-plugin-revision
```

Create release tag and release:

```sh
# Create local annotated tag from current versions
./scripts/release.sh create-tag

# Create and push tag in one step
./scripts/release.sh create-tag --push

# Create a GitHub release with the computed tag (requires gh CLI auth)
./scripts/release.sh create-gh-release
```

`create-gh-release` creates the GitHub release directly (and auto-generates
release notes by default), which triggers publishing to GitHub Pages.

Recommended release flow:

1. bump versions (`set-gatus`, `set-plugin`, or revision bump commands)
2. commit + push to `master`
3. create release (`./scripts/release.sh create-gh-release`)
4. wait for `.github/workflows/release.yml` to publish Pages

Published layout:

- `https://<owner>.github.io/<repo>/<ABI>/...`
- example ABI path for this build: `FreeBSD:14:amd64`

To enable publishing, set repository Pages source to **GitHub Actions**.

## Integrate the repo in OPNsense (automatic updates)

Create a pkg repository file on the firewall:

```sh
cat >/usr/local/etc/pkg/repos/gatus.conf <<'EOF'
gatus: {
  url: "https://daniel-k.github.io/opnsense-plugin-gatus/${ABI}",
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
