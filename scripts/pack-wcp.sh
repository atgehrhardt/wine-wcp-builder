#!/usr/bin/env bash
# pack-wcp.sh – Package Wine PE DLLs as a Winlator-compatible WCP file
# Usage: pack-wcp.sh <version> <source> [commit_sha]
#
# WCP format: zstd-compressed GNU tar archive containing:
#   profile.json  – package metadata
#   system32/     – 64-bit Windows PE DLLs
#   syswow64/     – 32-bit Windows PE DLLs (wow64 compat)
set -euo pipefail

VERSION="${1:?Usage: pack-wcp.sh <version> <source> [commit_sha]}"
SOURCE="${2:?}"
COMMIT_SHA="${3:-}"

WORK_DIR="${GITHUB_WORKSPACE:-$(pwd)}/build"
OUTPUT_DIR="${GITHUB_WORKSPACE:-$(pwd)}/output"
STAGE_DIR="${WORK_DIR}/wcp-stage"

PE64_DIR="${WORK_DIR}/wine-pe-x86_64"
PE32_DIR="${WORK_DIR}/wine-pe-i686"

mkdir -p "${OUTPUT_DIR}" "${STAGE_DIR}/system32" "${STAGE_DIR}/syswow64"

# ── Collect DLLs ─────────────────────────────────────────────────────────
echo "==> Collecting 64-bit DLLs..."
# Wine installs to ${prefix}/lib/wine/x86_64-windows/ for PE DLLs
WIN64_SRC=$(find "${PE64_DIR}" -type d \( \
  -name "x86_64-windows" \
  -o -name "system32" \
  -o -name "wine" \
\) | head -1)

if [ -z "${WIN64_SRC}" ]; then
  echo "ERROR: Could not find 64-bit DLL directory under ${PE64_DIR}" >&2
  find "${PE64_DIR}" -name "*.dll" | head -5
  exit 1
fi

# Copy DLLs, preserve structure
find "${WIN64_SRC}" -maxdepth 1 -name "*.dll" \
  | sort | xargs -I{} cp {} "${STAGE_DIR}/system32/"

echo "  64-bit DLLs: $(ls "${STAGE_DIR}/system32/"*.dll 2>/dev/null | wc -l)"

if [ -d "${PE32_DIR}" ]; then
  echo "==> Collecting 32-bit DLLs (syswow64)..."
  WIN32_SRC=$(find "${PE32_DIR}" -type d \( \
    -name "i386-windows" \
    -o -name "syswow64" \
    -o -name "wine" \
  \) | head -1)

  if [ -n "${WIN32_SRC}" ]; then
    find "${WIN32_SRC}" -maxdepth 1 -name "*.dll" \
      | sort | xargs -I{} cp {} "${STAGE_DIR}/syswow64/"
    echo "  32-bit DLLs: $(ls "${STAGE_DIR}/syswow64/"*.dll 2>/dev/null | wc -l)"
  fi
fi

# Also copy EXE utilities (wineboot, explorer, etc.) into system32
find "${PE64_DIR}" -name "*.exe" \
  | sort | xargs -I{} cp {} "${STAGE_DIR}/system32/" 2>/dev/null || true

# ── Build file list for profile.json ────────────────────────────────────
echo "==> Building profile.json..."

build_file_list() {
  local DIR="$1"
  local TARGET_VAR="$2"   # e.g. "${system32}"

  find "${DIR}" -maxdepth 1 \( -name "*.dll" -o -name "*.exe" \) \
    | sort \
    | while read -r F; do
        BASENAME=$(basename "${F}")
        printf '    {"source": "%s/%s", "target": "%s/%s"}' \
          "$(basename "${DIR}")" "${BASENAME}" \
          "${TARGET_VAR}" "${BASENAME}"
      done \
    | paste -sd ',' -
}

FILES_64=$(build_file_list "${STAGE_DIR}/system32" '${system32}')
FILES_32=$(build_file_list "${STAGE_DIR}/syswow64" '${syswow64}')

# Combine file lists
if [ -n "${FILES_32}" ]; then
  ALL_FILES="${FILES_64},${FILES_32}"
else
  ALL_FILES="${FILES_64}"
fi

# Version code: strip dots and non-numerics, take first 6 digits
VERSION_CODE=$(echo "${VERSION}" | tr -d '.' | tr -cd '0-9' | cut -c1-6)

SOURCE_LABEL="Wine ${VERSION}"
[ "${SOURCE}" = "winlator" ] && SOURCE_LABEL="Wine ${VERSION} (Winlator fork)"
[ -n "${COMMIT_SHA}" ]       && SOURCE_LABEL="${SOURCE_LABEL} @ ${COMMIT_SHA}"

cat > "${STAGE_DIR}/profile.json" <<JSON
{
  "type": "wine",
  "versionName": "${VERSION}",
  "versionCode": ${VERSION_CODE},
  "description": "${SOURCE_LABEL} – PE DLLs for Winlator Bionic / GameNative",
  "files": [
${ALL_FILES}
  ]
}
JSON

echo "==> profile.json preview:"
cat "${STAGE_DIR}/profile.json" | head -20

# ── Produce WCP archive ──────────────────────────────────────────────────
WCP_NAME="wine-${VERSION}.wcp"
[ "${SOURCE}" = "winlator" ] && WCP_NAME="wine-winlator-${VERSION}.wcp"
WCP_PATH="${OUTPUT_DIR}/${WCP_NAME}"

echo "==> Creating WCP: ${WCP_NAME}"

# Deterministic, reproducible archive (same as WinlatorWCPHub's packing.sh)
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

# Export for workflow steps
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "wcp_path=${WCP_PATH}"   >> "${GITHUB_OUTPUT}"
  echo "wcp_name=${WCP_NAME}"   >> "${GITHUB_OUTPUT}"
  echo "wcp_sha256=${SHA256}"   >> "${GITHUB_OUTPUT}"
fi
