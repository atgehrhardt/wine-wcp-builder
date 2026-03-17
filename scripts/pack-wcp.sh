#!/usr/bin/env bash
# pack-wcp.sh – Package Wine PE DLLs as a Winlator-compatible WCP file
# Usage: pack-wcp.sh <version> <source> [commit_sha]
#
# WCP format: zstd-compressed GNU tar archive containing:
#   profile.json  – package metadata with "Wine" type and wine paths
#   bin/          – Wine executables
#   lib/wine/x86_64-windows/  – 64-bit PE DLLs
#   lib/wine/i386-windows/    – 32-bit PE DLLs (WoW64)
#   share/wine/   – NLS files, fonts
set -euo pipefail

VERSION="${1:?Usage: pack-wcp.sh <version> <source> [commit_sha]}"
SOURCE="${2:?}"
COMMIT_SHA="${3:-}"

WORK_DIR="${GITHUB_WORKSPACE:-$(pwd)}/build"
OUTPUT_DIR="${GITHUB_WORKSPACE:-$(pwd)}/output"
STAGE_DIR="${WORK_DIR}/wcp-stage"

PE64_DIR="${WORK_DIR}/wine-pe-x86_64"
PE32_DIR="${WORK_DIR}/wine-pe-i686"

rm -rf "${STAGE_DIR}"
mkdir -p "${OUTPUT_DIR}" "${STAGE_DIR}"

# ── Collect files from install prefixes ─────────────────────────────────
echo "==> Collecting Wine files..."

collect_tree() {
  local SRC="$1"
  local DEST="$2"

  if [ ! -d "${SRC}" ]; then
    echo "  [SKIP] ${SRC} not found"
    return
  fi

  # Copy lib/wine tree (preserves x86_64-windows/, i386-windows/ structure)
  if [ -d "${SRC}/lib" ]; then
    mkdir -p "${DEST}/lib"
    cp -a "${SRC}/lib/wine" "${DEST}/lib/" 2>/dev/null || true
  fi

  # Copy bin/
  if [ -d "${SRC}/bin" ]; then
    mkdir -p "${DEST}/bin"
    cp -a "${SRC}/bin/"* "${DEST}/bin/" 2>/dev/null || true
  fi

  # Copy share/wine/ (nls files, fonts)
  if [ -d "${SRC}/share/wine" ]; then
    mkdir -p "${DEST}/share"
    cp -a "${SRC}/share/wine" "${DEST}/share/" 2>/dev/null || true
  fi
}

collect_tree "${PE64_DIR}" "${STAGE_DIR}"
collect_tree "${PE32_DIR}" "${STAGE_DIR}"

# Strip debug symbols to reduce WCP size
echo "==> Stripping binaries..."
export PATH="/opt/llvm-mingw/bin:${PATH}"
find "${STAGE_DIR}" \( -name "*.dll" -o -name "*.exe" \) \
  | xargs -P"$(nproc)" -I{} x86_64-w64-mingw32-strip --strip-unneeded {} 2>/dev/null || true

# Count what we collected
DLL64=$(find "${STAGE_DIR}/lib/wine/x86_64-windows" -name "*.dll" 2>/dev/null | wc -l)
DLL32=$(find "${STAGE_DIR}/lib/wine/i386-windows" -name "*.dll" 2>/dev/null | wc -l)
EXES=$(find "${STAGE_DIR}" -name "*.exe" 2>/dev/null | wc -l)
echo "  64-bit DLLs: ${DLL64}"
echo "  32-bit DLLs: ${DLL32}"
echo "  EXEs: ${EXES}"

if [ "${DLL64}" -eq 0 ]; then
  echo "ERROR: No 64-bit DLLs found. Build likely failed." >&2
  find "${PE64_DIR}" -type f | head -20 >&2
  exit 1
fi

# ── Build file list for profile.json ────────────────────────────────────
echo "==> Building profile.json..."

build_file_list() {
  local BASE_DIR="$1"

  find "${BASE_DIR}" -type f \( -name "*.dll" -o -name "*.exe" -o -name "*.drv" -o -name "*.sys" \) \
    | sort \
    | while read -r FPATH; do
        REL=$(realpath --relative-to="${STAGE_DIR}" "${FPATH}")
        TARGET="${REL}"
        case "${REL}" in
          lib/wine/x86_64-windows/*) TARGET="\${system32}/$(basename "${REL}")" ;;
          lib/wine/i386-windows/*)   TARGET="\${syswow64}/$(basename "${REL}")" ;;
          bin/*)                     TARGET="\${bindir}/$(basename "${REL}")" ;;
        esac
        printf '    {"source": "%s", "target": "%s"}' "${REL}" "${TARGET}"
      done \
    | paste -sd ',' -
}

ALL_FILES=$(build_file_list "${STAGE_DIR}")

# Version code: strip dots and non-numerics, take first 6 digits
VERSION_CODE=$(echo "${VERSION}" | tr -d '.' | tr -cd '0-9' | cut -c1-6)

SOURCE_LABEL="Wine ${VERSION}"
[ "${SOURCE}" = "winlator" ] && SOURCE_LABEL="Wine ${VERSION} (Winlator fork)"
[ -n "${COMMIT_SHA}" ] && SOURCE_LABEL="${SOURCE_LABEL} @ ${COMMIT_SHA}"

cat > "${STAGE_DIR}/profile.json" <<JSON
{
  "type": "Wine",
  "versionName": "${VERSION}",
  "versionCode": ${VERSION_CODE},
  "description": "${SOURCE_LABEL} – PE DLLs for Winlator Bionic / GameNative",
  "wine": {
    "binPath": "bin",
    "libPath": "lib"
  },
  "files": [
${ALL_FILES}
  ]
}
JSON

echo "==> profile.json preview:"
head -20 "${STAGE_DIR}/profile.json"

# ── Produce WCP archive ──────────────────────────────────────────────────
WCP_NAME="wine-${VERSION}.wcp"
[ "${SOURCE}" = "winlator" ] && WCP_NAME="wine-winlator-${VERSION}.wcp"
WCP_PATH="${OUTPUT_DIR}/${WCP_NAME}"

echo "==> Creating WCP: ${WCP_NAME}"

tar \
  --zstd \
  --format=gnu \
  --numeric-owner \
  --owner=0 \
  --group=0 \
  --mtime='1970-01-01 00:00:00' \
  --sort=name \
  -cf "${WCP_PATH}" \
  -C "${STAGE_DIR}" \
  .

SIZE=$(du -sh "${WCP_PATH}" | cut -f1)
SHA256=$(sha256sum "${WCP_PATH}" | cut -d' ' -f1)

echo "==> WCP created!"
echo "    File:   ${WCP_PATH}"
echo "    Size:   ${SIZE}"
echo "    SHA256: ${SHA256}"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "wcp_path=${WCP_PATH}" >> "${GITHUB_OUTPUT}"
  echo "wcp_name=${WCP_NAME}" >> "${GITHUB_OUTPUT}"
  echo "wcp_sha256=${SHA256}" >> "${GITHUB_OUTPUT}"
fi
