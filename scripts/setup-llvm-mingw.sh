#!/usr/bin/env bash
# setup-llvm-mingw.sh – Download and install LLVM-MinGW toolchain
# Usage: setup-llvm-mingw.sh [VERSION]
set -euo pipefail

LLVM_VERSION="${1:-20251104}"
INSTALL_DIR="/opt/llvm-mingw"
CACHE_DIR="${HOME}/.cache/wine-build/llvm-mingw"

ARCHIVE="llvm-mingw-${LLVM_VERSION}-ucrt-ubuntu-22.04-x86_64.tar.xz"
URL="https://github.com/mstorsjo/llvm-mingw/releases/download/${LLVM_VERSION}/${ARCHIVE}"

# Skip if already installed at this version
if [ -f "${INSTALL_DIR}/.version" ] && \
   [ "$(cat "${INSTALL_DIR}/.version")" = "${LLVM_VERSION}" ]; then
  echo "LLVM-MinGW ${LLVM_VERSION} already installed at ${INSTALL_DIR}"
  export PATH="${INSTALL_DIR}/bin:${PATH}"
  exit 0
fi

mkdir -p "${CACHE_DIR}"

ARCHIVE_PATH="${CACHE_DIR}/${ARCHIVE}"
if [ ! -f "${ARCHIVE_PATH}" ]; then
  echo "Downloading LLVM-MinGW ${LLVM_VERSION}..."
  curl -fsSL --retry 5 "${URL}" -o "${ARCHIVE_PATH}"
else
  echo "Using cached LLVM-MinGW archive."
fi

echo "Installing LLVM-MinGW to ${INSTALL_DIR}..."
sudo rm -rf "${INSTALL_DIR}"
sudo mkdir -p "${INSTALL_DIR}"
sudo tar -xf "${ARCHIVE_PATH}" --strip-components=1 -C "${INSTALL_DIR}"
echo "${LLVM_VERSION}" | sudo tee "${INSTALL_DIR}/.version" > /dev/null

# Persist PATH in GITHUB_PATH if running inside GitHub Actions
if [ -n "${GITHUB_PATH:-}" ]; then
  echo "${INSTALL_DIR}/bin" >> "${GITHUB_PATH}"
fi

export PATH="${INSTALL_DIR}/bin:${PATH}"

echo "LLVM-MinGW ${LLVM_VERSION} ready."
echo "  x86_64-w64-mingw32-gcc: $(x86_64-w64-mingw32-gcc --version | head -1)"
echo "  i686-w64-mingw32-gcc:   $(i686-w64-mingw32-gcc --version | head -1)"
