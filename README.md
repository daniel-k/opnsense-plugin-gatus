# opnsense-plugin-gatus

Builds two packages for OPNsense amd64:

- `gatus` (FreeBSD port package)
- `os-gatus` (OPNsense plugin with web UI)

The plugin provides a `Services -> Gatus` page where you can:

- enable/disable the service
- tune runtime options (user, log level, startup delay)
- edit the full `gatus.yaml` file from the UI

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

`${ABI}` is expanded by pkg from the FreeBSD base of the running OPNsense
release, so the repository has to carry a directory per supported ABI.

## Supported targets

| OPNsense | FreeBSD base | pkg ABI             | built on FreeBSD |
| -------- | ------------ | ------------------- | ---------------- |
| 26.7     | 15.1         | `FreeBSD:15:amd64`  | 15.1             |
| 26.1     | 14.3         | `FreeBSD:14:amd64`  | 14.3             |

Packages are built per target and published side by side, so one repository URL
serves every supported release.

A major OPNsense upgrade changes `${ABI}`. If this repository does not yet carry
a directory for the new ABI, `pkg update` fails with a 404 on `meta.conf`, which
in turn makes the OPNsense firmware page fail to check for updates. See
[Troubleshooting](#troubleshooting).

The build target list lives in the `strategy.matrix` of both workflow files; add
an entry there (and keep both files in sync) when a new OPNsense release moves
to a new FreeBSD major version.

## Repository layout

- `ports/www/gatus`: FreeBSD port for `gatus`
- `net-mgmt/gatus`: OPNsense plugin sources (`os-gatus`)
- `Mk`, `Templates`, `Scripts`, `Keywords`: OPNsense plugin build tooling

## Build locally (FreeBSD)

```sh
./scripts/build-packages.sh
```

By default this builds the release plugin package (`os-gatus`), even though
the OPNsense plugin tooling defaults to devel mode on master branches.

To intentionally build the devel plugin package (`os-gatus-devel`):

```sh
PLUGIN_DEVEL_MODE=devel ./scripts/build-packages.sh
```

Environment variables understood by `scripts/build-packages.sh`:

- `PLUGIN_DEVEL_MODE` (`release` / `devel`, default `release`)
- `PLUGIN_ABIS`: OPNsense release the plugin is annotated for (`product_abi`,
  for example `26.7`). Unset means `opnsense-version -a` when building on a
  firewall, otherwise the fallback in `Mk/defaults.mk`
- `EXPECTED_PKG_ABI`: abort unless `pkg config ABI` equals this value (for
  example `FreeBSD:15:amd64`). The pkg ABI comes from the FreeBSD major version
  of the build host, so this guards against publishing packages the firewall
  will refuse to install
- `PORTSDIR`: ports tree to build the `gatus` port against (default
  `/usr/ports`)
- `DISTDIR`: where ports keep fetched distfiles (default
  `${PORTSDIR}/distfiles`); CI points this at its download cache

Prerequisite: a FreeBSD ports tree at `/usr/ports`, or `PORTSDIR` pointing at
one (for example:
`git clone --depth 1 https://git.FreeBSD.org/ports.git /usr/ports`).

Artifacts end up in `artifacts/All/`:

- `gatus-<version>.pkg`
- `os-gatus-<version>.pkg` (or `os-gatus-devel-<version>.pkg` when
  `PLUGIN_DEVEL_MODE=devel`)
- repository metadata (`packagesite.pkg`, `meta.conf`, ...)
- ABI marker (`artifacts/ABI`, used to place the packages in the published repo)

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
   If you built with `PLUGIN_DEVEL_MODE=devel`, install
   `os-gatus-devel-<version>.pkg` instead.
4. Open `Services -> Gatus` in the web UI and configure/save.

## CI

GitHub Actions is split into two workflows:

1. `.github/workflows/build.yml` (push/PR/manual): builds both packages on
   FreeBSD and uploads them as an artifact (no publishing)
2. `.github/workflows/release.yml` (GitHub release `published`): rebuilds both
   packages and publishes the pkg repository to GitHub Pages

Both workflows run a matrix over the targets in
[Supported targets](#supported-targets), one job per FreeBSD release. The
release workflow collects every matrix job's artifact and deploys all ABIs in a
single Pages deployment, because a Pages deployment replaces the whole site.

Release assets carry an ABI suffix (for example
`os-gatus-1.1_2-freebsd-15-amd64.pkg`), since GitHub asset names are unique per
release.

Only explicit GitHub releases publish to Pages.

Both workflows use a GitHub Actions cache for:

- `/usr/ports/distfiles` (source tarballs/patches fetched by ports)
- `/var/cache/pkg` (`pkg` download cache)

This reduces repeated network downloads on later runs. A new cache is populated
automatically after a cache miss.

### Refreshing the CI cache (important)

Cache key version is defined in both `.github/workflows/build.yml` and
`.github/workflows/release.yml` as:
`freebsd-<release>-downloads-v2-...`

The FreeBSD release is part of the key, so matrix jobs do not share a cache and
adding a new target does not need a key bump.

To force a fresh cache generation, bump the `v2` part (for example to `v3`),
commit, and push (keep both workflow files in sync). The first run after the
bump is expected to be slower (cold cache). The next runs should be faster
again.

The VM also gets `IGNORE_OSVERSION` set, because FreeBSD's package repository
for a branch tracks its newest minor release and is regularly ahead of the VM
image (a 14.4 repo on a 14.3 image). This only affects build dependencies
fetched during the build; packages produced by a job are stamped with the build
host's version, which is what the targeted OPNsense release expects.

When to refresh on purpose:

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
- one directory per supported ABI, for example `FreeBSD:15:amd64` and
  `FreeBSD:14:amd64`

To enable publishing, set repository Pages source to **GitHub Actions**.

## Troubleshooting

### After a major OPNsense upgrade, `pkg update` and the firmware page fail

A major OPNsense upgrade can change the FreeBSD base and therefore `${ABI}`
(26.1 → 26.7 moved from `FreeBSD:14:amd64` to `FreeBSD:15:amd64`). Until this
repository publishes packages for the new ABI, pkg gets a 404 for
`<url>/meta.conf`. `pkg update` then exits non-zero, and because OPNsense runs
`pkg update` across all configured repositories, the firmware page reports that
it cannot check for updates — even for OPNsense's own packages.

Check which ABI the firewall asks for:

```sh
pkg config ABI
fetch -o /dev/null "https://daniel-k.github.io/opnsense-plugin-gatus/$(pkg config ABI)/meta.conf"
```

To get OPNsense updating again immediately, disable this repository:

```sh
sed -i '' 's/enabled: yes/enabled: no/' /usr/local/etc/pkg/repos/gatus.conf
pkg update -f
```

Once packages for the new ABI are published, re-enable it and reinstall so the
packages match the new base:

```sh
sed -i '' 's/enabled: no/enabled: yes/' /usr/local/etc/pkg/repos/gatus.conf
pkg update -f
pkg upgrade -f gatus os-gatus
```

The old packages stay installed across the upgrade but were built for the
previous FreeBSD major version, so reinstalling them from the new ABI directory
is what actually fixes the plugin.
