#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
ARTIFACT_ROOT=${1:-"${ROOT_DIR}/artifacts"}
PACKAGES_DIR="${ARTIFACT_ROOT}/All"

mkdir -p "${PACKAGES_DIR}"

if ! command -v pkg >/dev/null 2>&1; then
    echo "error: pkg(8) is required (run this on FreeBSD/OPNsense)" >&2
    exit 1
fi

if [ ! -f /usr/ports/Mk/bsd.port.mk ]; then
    echo "error: /usr/ports is required (install the FreeBSD ports tree first)" >&2
    exit 1
fi

echo "==> Building gatus package"
make -C "${ROOT_DIR}/ports/www/gatus" clean package BATCH=yes PACKAGES="${ARTIFACT_ROOT}"

GATUS_PKG=$(find "${PACKAGES_DIR}" -maxdepth 1 -type f -name 'gatus-*.pkg' | head -n 1)
if [ -z "${GATUS_PKG}" ]; then
    echo "error: gatus package was not produced" >&2
    exit 1
fi

echo "==> Installing local gatus package for plugin dependency resolution"
pkg add -f "${GATUS_PKG}"

echo "==> Building os-gatus plugin package"
rm -rf "${ROOT_DIR}/net-mgmt/gatus/work"
make -C "${ROOT_DIR}/net-mgmt/gatus" package
cp "${ROOT_DIR}/net-mgmt/gatus"/work/pkg/*.pkg "${PACKAGES_DIR}/"

echo "==> Generating pkg repository metadata"
pkg repo "${PACKAGES_DIR}"

echo "==> Recording package ABI"
pkg config ABI > "${ARTIFACT_ROOT}/ABI"

echo "==> Build output"
ls -1 "${PACKAGES_DIR}"
