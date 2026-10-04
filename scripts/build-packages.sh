#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
ARTIFACT_ROOT=${1:-"${ROOT_DIR}/artifacts"}
PACKAGES_DIR="${ARTIFACT_ROOT}/All"
PLUGIN_DEVEL_MODE=${PLUGIN_DEVEL_MODE:-release}

# OPNsense release the plugin is annotated for (`product_abi`). Empty lets the
# plugin tooling decide: `opnsense-version -a` when building on a firewall,
# otherwise the fallback in Mk/defaults.mk.
PLUGIN_ABIS=${PLUGIN_ABIS:-}

# When set, the build aborts unless pkg(8) on this host produces exactly this
# ABI. The pkg ABI follows the FreeBSD major version of the build host, so this
# catches building e.g. FreeBSD:14:amd64 packages for a FreeBSD 15 based
# OPNsense, which pkg on the firewall would then refuse to install.
EXPECTED_PKG_ABI=${EXPECTED_PKG_ABI:-}

# FreeBSD ports tree the gatus port is built against.
PORTSDIR=${PORTSDIR:-/usr/ports}

# Where ports keep fetched distfiles. Empty uses the ports default
# (${PORTSDIR}/distfiles); CI points it at a cached directory.
DISTDIR=${DISTDIR:-}

mkdir -p "${PACKAGES_DIR}"

if ! command -v pkg >/dev/null 2>&1; then
    echo "error: pkg(8) is required (run this on FreeBSD/OPNsense)" >&2
    exit 1
fi

PKG_ABI=$(pkg config ABI)

if [ -n "${EXPECTED_PKG_ABI}" ] && [ "${PKG_ABI}" != "${EXPECTED_PKG_ABI}" ]; then
    echo "error: this host builds for ABI '${PKG_ABI}', expected '${EXPECTED_PKG_ABI}'" >&2
    echo "       build on a FreeBSD release matching the targeted OPNsense base" >&2
    exit 1
fi

if [ ! -f "${PORTSDIR}/Mk/bsd.port.mk" ]; then
    echo "error: '${PORTSDIR}' is not a FreeBSD ports tree" >&2
    echo "       install the ports tree there or point PORTSDIR at one" >&2
    exit 1
fi

echo "==> Build target"
echo "    pkg ABI:      ${PKG_ABI}"
echo "    OPNsense ABI: ${PLUGIN_ABIS:-<plugin tooling default>}"
echo "    ports tree:   ${PORTSDIR}"

echo "==> Building gatus package"
set -- clean package BATCH=yes PACKAGES="${ARTIFACT_ROOT}" PORTSDIR="${PORTSDIR}"
if [ -n "${DISTDIR}" ]; then
    set -- "$@" DISTDIR="${DISTDIR}"
fi
make -C "${ROOT_DIR}/ports/www/gatus" "$@"

GATUS_PKG=$(find "${PACKAGES_DIR}" -maxdepth 1 -type f -name 'gatus-*.pkg' | head -n 1)
if [ -z "${GATUS_PKG}" ]; then
    echo "error: gatus package was not produced" >&2
    exit 1
fi

echo "==> Installing local gatus package for plugin dependency resolution"
pkg add -f "${GATUS_PKG}"

case "${PLUGIN_DEVEL_MODE}" in
    release)
        echo "==> Building os-gatus plugin package (release variant)"
        PLUGIN_DEVEL_FLAG=
        ;;
    devel)
        echo "==> Building os-gatus plugin package (devel variant)"
        PLUGIN_DEVEL_FLAG=yes
        ;;
    *)
        echo "error: PLUGIN_DEVEL_MODE must be either 'release' or 'devel'" >&2
        exit 1
        ;;
esac

set -- _PLUGIN_DEVEL="${PLUGIN_DEVEL_FLAG}"
if [ -n "${PLUGIN_ABIS}" ]; then
    set -- "$@" PLUGIN_ABIS="${PLUGIN_ABIS}"
fi

rm -rf "${ROOT_DIR}/net-mgmt/gatus/work"
make -C "${ROOT_DIR}/net-mgmt/gatus" "$@" package
cp "${ROOT_DIR}/net-mgmt/gatus"/work/pkg/*.pkg "${PACKAGES_DIR}/"

echo "==> Generating pkg repository metadata"
pkg repo "${PACKAGES_DIR}"

echo "==> Recording package ABI"
printf '%s\n' "${PKG_ABI}" > "${ARTIFACT_ROOT}/ABI"

echo "==> Build output"
ls -1 "${PACKAGES_DIR}"

echo "==> Package ABIs"
for PKG_FILE in "${PACKAGES_DIR}"/gatus-*.pkg "${PACKAGES_DIR}"/os-gatus-*.pkg; do
    [ -f "${PKG_FILE}" ] || continue
    printf '    %s: arch=%s product_abi=%s\n' \
        "$(basename "${PKG_FILE}")" \
        "$(pkg query -F "${PKG_FILE}" '%q')" \
        "$(pkg query -F "${PKG_FILE}" '%At %Av' | awk '$1 == "product_abi" { print $2 }')"
done
