#!/usr/bin/env bash
# download-wine.sh – Fetch Wine source code
# Usage: download-wine.sh <source> <version>
#   source:  "upstream" | "winlator"
#   version: version string (e.g. "10.0" for upstream, tag for winlator)
set -euo pipefail

SOURCE="${1:?Usage: download-wine.sh <upstream|winlator> <version>}"
VERSION="${2:?Usage: download-wine.sh <upstream|winlator> <version>}"

CACHE_DIR="${HOME}/.cache/wine-build/src"
WORK_DIR="${GITHUB_WORKSPACE:-$(pwd)}/build"
mkdir -p "${CACHE_DIR}" "${WORK_DIR}"

case "${SOURCE}" in
  upstream)
    # Official Wine tarballs from dl.winehq.org
    MAJOR="${VERSION%%.*}"
    TARBALL="wine-${VERSION}.tar.xz"
    URL="https://dl.winehq.org/wine/source/${MAJOR}.x/${TARBALL}"
    CACHED="${CACHE_DIR}/${TARBALL}"
    DEST="${WORK_DIR}/wine-src"

    if [ ! -f "${CACHED}" ]; then
      echo "Downloading Wine ${VERSION} from dl.winehq.org..."
      curl -fsSL --retry 5 "${URL}" -o "${CACHED}"
    else
      echo "Using cached tarball: ${CACHED}"
    fi

    echo "Extracting..."
    rm -rf "${DEST}"
    tar -xf "${CACHED}" -C "${WORK_DIR}"
    mv "${WORK_DIR}/wine-${VERSION}" "${DEST}"
    ;;

  winlator)
    # brunodev85's patched Wine fork
    REPO="brunodev85/wine-9.2-custom"
    REF="${VERSION}"  # tag or branch
    ARCHIVE="${CACHE_DIR}/winlator-wine-${VERSION}.tar.gz"
    DEST="${WORK_DIR}/wine-src"

    if [ ! -f "${ARCHIVE}" ]; then
      echo "Downloading Winlator Wine fork (${REPO}@${REF})..."
      curl -fsSL --retry 5 \
        "https://github.com/${REPO}/archive/${REF}.tar.gz" \
        -o "${ARCHIVE}"
    else
      echo "Using cached Winlator fork archive."
    fi

    echo "Extracting..."
    rm -rf "${DEST}"
    mkdir -p "${DEST}"
    tar -xf "${ARCHIVE}" --strip-components=1 -C "${DEST}"
    ;;

  *)
    echo "ERROR: Unknown source '${SOURCE}'. Use 'upstream' or 'winlator'." >&2
    exit 1
    ;;
esac

echo "Wine source ready at: ${WORK_DIR}/wine-src"
echo "WINE_SRC=${WORK_DIR}/wine-src" >> "${GITHUB_ENV:-/dev/null}"
