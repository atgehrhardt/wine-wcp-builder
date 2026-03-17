#!/usr/bin/env bash
# build-wine-tools.sh – Build native Wine tools (wrc, widl, winebuild)
# These run on the x86_64 build host and are required when cross-compiling.
set -euo pipefail

WORK_DIR="${GITHUB_WORKSPACE:-$(pwd)}/build"
WINE_SRC="${WORK_DIR}/wine-src"
TOOLS_BUILD="${WORK_DIR}/wine-tools-build"
TOOLS_INSTALL="${WORK_DIR}/wine-tools"
JOBS="${JOBS:-$(nproc)}"

mkdir -p "${TOOLS_BUILD}" "${TOOLS_INSTALL}"

echo "==> Configuring native Wine tools..."
cd "${TOOLS_BUILD}"

# We only need the build tools – disable everything else for speed.
"${WINE_SRC}/configure" \
  --prefix="${TOOLS_INSTALL}" \
  --enable-win64 \
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
  --disable-tests \
  2>&1 | tail -5

echo "==> Building native Wine tools (${JOBS} jobs)..."
make -C "${TOOLS_BUILD}" -j"${JOBS}" \
  tools/wrc/wrc \
  tools/widl/widl \
  tools/winebuild/winebuild \
  tools/winegcc/winegcc \
  tools/wmc/wmc \
  tools/sfnt2fon/sfnt2fon \
  tools/wine \
  2>&1 | tail -20

# --with-wine-tools expects the build directory itself (not an install prefix)
# The PE cross-compile step uses this path to find wrc, widl, etc.
echo "==> Native tools built at: ${TOOLS_BUILD}"
ls "${TOOLS_BUILD}/tools/wrc/wrc" \
   "${TOOLS_BUILD}/tools/widl/widl" \
   "${TOOLS_BUILD}/tools/winebuild/winebuild" 2>/dev/null

# Export the build directory as WINE_TOOLS_DIR
echo "WINE_TOOLS_DIR=${TOOLS_BUILD}" >> "${GITHUB_ENV:-/dev/null}"
