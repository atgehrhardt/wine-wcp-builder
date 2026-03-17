#!/usr/bin/env bash
# apply-patches.sh – Apply patches to Wine source for Android/Winlator compatibility
# Usage: apply-patches.sh <source> <version>
#
# For "winlator" source: the fork is already patched – we only apply local extras.
# For "upstream" source: we download and apply Wine Staging, then local patches.
set -euo pipefail

SOURCE="${1:?Usage: apply-patches.sh <upstream|winlator> <version>}"
VERSION="${2:?}"

WORK_DIR="${GITHUB_WORKSPACE:-$(pwd)}/build"
WINE_SRC="${WORK_DIR}/wine-src"
PATCHES_DIR="${GITHUB_WORKSPACE:-$(pwd)}/patches"
CACHE_DIR="${HOME}/.cache/wine-build/patches"
mkdir -p "${CACHE_DIR}"

apply_patch() {
  local PATCH_FILE="$1"
  local STRIP="${2:-1}"
  echo "  Applying: $(basename "${PATCH_FILE}")"
  patch -d "${WINE_SRC}" -p"${STRIP}" --forward --batch \
    < "${PATCH_FILE}" || {
    # Some patches may already be applied (idempotent)
    echo "  [WARN] Patch may already be applied or had conflicts – continuing."
  }
}

# ── Wine Staging (upstream only) ────────────────────────────────────────────
if [ "${SOURCE}" = "upstream" ]; then
  STAGING_VERSION="wine-staging-${VERSION}"
  STAGING_ARCHIVE="${CACHE_DIR}/wine-staging-${VERSION}.tar.gz"
  STAGING_DIR="${WORK_DIR}/wine-staging-${VERSION}"

  echo "==> Fetching Wine Staging ${VERSION}..."
  if [ ! -f "${STAGING_ARCHIVE}" ]; then
    curl -fsSL --retry 5 \
      "https://github.com/wine-staging/wine-staging/archive/refs/tags/v${VERSION}.tar.gz" \
      -o "${STAGING_ARCHIVE}" || {
      # Staging might not have a tag for every minor upstream release
      echo "[WARN] Wine Staging v${VERSION} not found – trying main branch."
      curl -fsSL --retry 5 \
        "https://github.com/wine-staging/wine-staging/archive/refs/heads/master.tar.gz" \
        -o "${STAGING_ARCHIVE}"
    }
  fi

  rm -rf "${STAGING_DIR}"
  mkdir -p "${STAGING_DIR}"
  tar -xf "${STAGING_ARCHIVE}" --strip-components=1 -C "${STAGING_DIR}"

  echo "==> Applying Wine Staging patches..."
  if [ -x "${STAGING_DIR}/staging/patchinstall.py" ]; then
    python3 "${STAGING_DIR}/staging/patchinstall.py" \
      --backend=patch \
      --all \
      -W winhlp32-Flex_Workaround \
      DESTDIR="${WINE_SRC}" \
    || echo "[WARN] patchinstall.py finished with warnings – continuing."
  else
    # Older staging layout
    pushd "${WINE_SRC}" > /dev/null
    "${STAGING_DIR}/patches/patchinstall.sh" DESTDIR="${WINE_SRC}" --all \
      || echo "[WARN] patchinstall.sh finished with warnings."
    popd > /dev/null
  fi
fi

# ── Local patches (applied for both sources) ───────────────────────────────
echo "==> Applying local patches from ${PATCHES_DIR}..."

# Apply patches in numeric order (001-*.patch, 002-*.patch, ...)
for PATCH in $(ls "${PATCHES_DIR}"/*.patch 2>/dev/null | sort); do
  apply_patch "${PATCH}"
done

echo "==> All patches applied."
