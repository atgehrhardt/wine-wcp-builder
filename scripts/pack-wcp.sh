#!/usr/bin/env bash
# pack-wcp.sh – Package Wine build output as WCP files for GameNative/Winlator
# Usage: pack-wcp.sh <x86_64|aarch64>
#
# Produces two WCPs per architecture:
#   wine-VERSION-ARCH.wcp     – type "Wine" for GameNative
#   wine-VERSION-ARCH.wcp.xz  – type "Wine" for Winlator CMOD / Ludashi
set -euo pipefail

BUILD_ARCH="${1:?Usage: pack-wcp.sh <x86_64|aarch64>}"

PROTON_VERSION="${PROTON_VERSION:-10.0-4}"
OUTPUT_DIR="${GITHUB_WORKSPACE:-$(pwd)}/output"

# Determine arch-specific paths
if [ "${BUILD_ARCH}" = "x86_64" ]; then
  COMPILED_DIR="$HOME/compiled-files-x86_64"
  ARCH_NAME="x86_64"
else
  COMPILED_DIR="$HOME/compiled-files-aarch64"
  ARCH_NAME="arm64ec"
fi

PREFIX_PACK="${GITHUB_WORKSPACE:-$(pwd)}/prefixPack.txz"

mkdir -p "${OUTPUT_DIR}"

# Verify build output exists
if [ ! -d "${COMPILED_DIR}/bin" ] || [ ! -d "${COMPILED_DIR}/lib" ]; then
  echo "ERROR: Build output not found at ${COMPILED_DIR}" >&2
  echo "Expected bin/ and lib/ directories." >&2
  exit 1
fi

if [ ! -f "${PREFIX_PACK}" ]; then
  echo "ERROR: prefixPack.txz not found at ${PREFIX_PACK}" >&2
  exit 1
fi

echo "==> Packaging WCP for ${ARCH_NAME}..."
echo "    Source: ${COMPILED_DIR}"
echo "    Binaries: $(find "${COMPILED_DIR}/bin" -type f | wc -l)"
echo "    Libraries: $(find "${COMPILED_DIR}/lib" -type f -name '*.so' | wc -l) .so files"
echo "    PE DLLs: $(find "${COMPILED_DIR}/lib" -type f -name '*.dll' | wc -l) .dll files"

cd "${COMPILED_DIR}"

# Copy prefixPack
cp "${PREFIX_PACK}" ./prefixPack.txz

# ── Generate profile.json (Wine type for GameNative) ────────────────────
cat > profile.json <<EOF
{
  "type": "Wine",
  "versionName": "${PROTON_VERSION}-${ARCH_NAME}",
  "versionCode": 0,
  "description": "Wine ${PROTON_VERSION} ${ARCH_NAME} - Windows compatibility layer for GameNative",
  "files": [],
  "wine": {
    "binPath": "bin",
    "libPath": "lib",
    "prefixPack": "prefixPack.txz"
  }
}
EOF

echo "==> profile.json:"
cat profile.json

# ── Create Wine WCP (xz-compressed tar) for GameNative ─────────────────
WCP_NAME="wine-${PROTON_VERSION}-${ARCH_NAME}.wcp"
echo "==> Creating ${WCP_NAME}..."
tar cJf "${OUTPUT_DIR}/${WCP_NAME}" bin lib share prefixPack.txz profile.json

# ── Create Wine WCP.xz for Winlator CMOD / Ludashi ─────────────────────
WCP_XZ_NAME="wine-${PROTON_VERSION}-${ARCH_NAME}.wcp.xz"
echo "==> Creating ${WCP_XZ_NAME}..."
# Same contents, same format, just different filename convention
cp "${OUTPUT_DIR}/${WCP_NAME}" "${OUTPUT_DIR}/${WCP_XZ_NAME}"

# ── Report ──────────────────────────────────────────────────────────────
echo ""
echo "==> WCP files created:"
for f in "${OUTPUT_DIR}/${WCP_NAME}" "${OUTPUT_DIR}/${WCP_XZ_NAME}"; do
  SIZE=$(du -sh "${f}" | cut -f1)
  SHA256=$(sha256sum "${f}" | cut -d' ' -f1)
  echo "    $(basename "${f}"): ${SIZE} (sha256: ${SHA256})"
done

# Clean up
rm -f prefixPack.txz profile.json
