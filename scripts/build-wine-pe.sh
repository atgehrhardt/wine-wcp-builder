#!/usr/bin/env bash
# build-wine-pe.sh – Cross-compile Wine Windows PE DLLs using LLVM-MinGW
# Usage: build-wine-pe.sh <x86_64|i686>
#
# Output: build/wine-pe-{arch}/  (DLL files ready for WCP packaging)
set -euo pipefail

ARCH="${1:?Usage: build-wine-pe.sh <x86_64|i686>}"

WORK_DIR="${GITHUB_WORKSPACE:-$(pwd)}/build"
WINE_SRC="${WORK_DIR}/wine-src"
TOOLS_DIR="${WINE_TOOLS_DIR:-${WORK_DIR}/wine-tools}"
BUILD_DIR="${WORK_DIR}/wine-pe-${ARCH}-build"
INSTALL_DIR="${WORK_DIR}/wine-pe-${ARCH}"
JOBS="${JOBS:-$(nproc)}"

# MinGW triple
case "${ARCH}" in
  x86_64)
    MINGW_TRIPLE="x86_64-w64-mingw32"
    WINE_OPTS="--enable-win64"
    ;;
  i686)
    MINGW_TRIPLE="i686-w64-mingw32"
    WINE_OPTS="--enable-wow64"   # 32-bit inside a 64-bit prefix
    ;;
  *)
    echo "ERROR: Unsupported architecture: ${ARCH}" >&2
    exit 1
    ;;
esac

export PATH="/opt/llvm-mingw/bin:${PATH}"

# Verify toolchain
if ! command -v "${MINGW_TRIPLE}-gcc" &>/dev/null; then
  echo "ERROR: ${MINGW_TRIPLE}-gcc not found. Run setup-llvm-mingw.sh first." >&2
  exit 1
fi

echo "==> Configuring Wine PE (${ARCH}) DLLs..."
mkdir -p "${BUILD_DIR}" "${INSTALL_DIR}"
cd "${BUILD_DIR}"

"${WINE_SRC}/configure" \
  --host="${MINGW_TRIPLE}" \
  --with-wine-tools="${TOOLS_DIR}" \
  --prefix="${INSTALL_DIR}" \
  ${WINE_OPTS} \
  \
  --without-x \
  --without-freetype \
  --without-gnutls \
  --without-gstreamer \
  --without-vulkan \
  --without-opengl \
  --without-cups \
  --without-dbus \
  --without-fontconfig \
  --without-ldap \
  --without-openal \
  --without-pulse \
  --without-sane \
  --without-v4l2 \
  --without-sdl \
  --without-udev \
  --without-usb \
  --without-krb5 \
  --without-opencl \
  \
  --disable-tests \
  --disable-mscoree \
  CROSSCC="${MINGW_TRIPLE}-gcc" \
  CROSSCXX="${MINGW_TRIPLE}-g++" \
  CROSSAR="${MINGW_TRIPLE}-ar" \
  CROSSRANLIB="${MINGW_TRIPLE}-ranlib" \
  CROSSSTRIP="${MINGW_TRIPLE}-strip" \
  2>&1 | tail -10

echo "==> Building Wine PE DLLs (${JOBS} jobs)..."
make -C "${BUILD_DIR}" -j"${JOBS}" \
  2>&1 | grep -E "^(Making|Error|error:)" || true

echo "==> Installing Wine PE DLLs to ${INSTALL_DIR}..."
make -C "${BUILD_DIR}" -j"${JOBS}" install

# Strip debug symbols from DLLs to reduce WCP size
echo "==> Stripping DLLs..."
find "${INSTALL_DIR}" -name "*.dll" -o -name "*.exe" -o -name "*.so" \
  | xargs -P"${JOBS}" -I{} "${MINGW_TRIPLE}-strip" --strip-unneeded {} 2>/dev/null || true

echo "==> Wine PE (${ARCH}) built."
echo "    DLL count: $(find "${INSTALL_DIR}" -name "*.dll" | wc -l)"
echo "    EXE count: $(find "${INSTALL_DIR}" -name "*.exe" | wc -l)"
