#!/usr/bin/env bash
# generate-patches.sh – Extract patches from the Winlator Wine fork vs upstream
# Usage: generate-patches.sh [winlator]
#
# This script diffs brunodev85/wine-9.2-custom against its closest upstream
# Wine tag and writes the result to patches/001-winlator-paths.patch.
# Run this locally to refresh patches when the Winlator fork is updated.
set -euo pipefail

WORK_DIR="${GITHUB_WORKSPACE:-$(pwd)}/build/patch-gen"
PATCHES_DIR="${GITHUB_WORKSPACE:-$(pwd)}/patches"
WINLATOR_REPO="https://github.com/brunodev85/wine-9.2-custom.git"
UPSTREAM_REPO="https://gitlab.winehq.org/wine/wine.git"

# The upstream Wine tag that the Winlator fork branched from
BASE_TAG="${WINLATOR_BASE_TAG:-wine-9.2}"

mkdir -p "${WORK_DIR}"

echo "==> Cloning Winlator Wine fork (shallow)..."
rm -rf "${WORK_DIR}/winlator-wine"
git clone --depth=50 "${WINLATOR_REPO}" "${WORK_DIR}/winlator-wine"

echo "==> Cloning upstream Wine (shallow, tag ${BASE_TAG})..."
rm -rf "${WORK_DIR}/upstream-wine"
git clone --depth=1 --branch "${BASE_TAG}" \
  "${UPSTREAM_REPO}" "${WORK_DIR}/upstream-wine"

echo "==> Generating diff..."
PATCH_FILE="${PATCHES_DIR}/001-winlator-paths.patch"

git diff \
  --no-index \
  --stat \
  "${WORK_DIR}/upstream-wine" \
  "${WORK_DIR}/winlator-wine" \
  | head -20 || true

git diff \
  --no-index \
  "${WORK_DIR}/upstream-wine" \
  "${WORK_DIR}/winlator-wine" \
  > "${PATCH_FILE}" || true

echo "==> Patch written to ${PATCH_FILE}"
echo "    Size: $(wc -l < "${PATCH_FILE}") lines"
echo ""
echo "Review the patch before committing:"
echo "  head -100 ${PATCH_FILE}"
