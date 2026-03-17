#!/usr/bin/env bash
# build-wine.sh – Configure, build, and install upstream Wine for Android/Bionic
# Usage: build-wine.sh <x86_64|aarch64> <--configure|--build|--install|--build-sysvshm>
#
# This replicates the cross-compilation logic from GameNative/proton-wine's
# build-step scripts, adapted for upstream Wine.
set -euo pipefail

BUILD_ARCH="${1:?Usage: build-wine.sh <x86_64|aarch64> <action>}"
shift

# ── Toolchain paths ────────────────────────────────────────────────────────
NDK_VERSION="${NDK_VERSION:-27.3.13750724}"
LLVM_MINGW_VERSION="${LLVM_MINGW_VERSION:-20250920}"

TOOLCHAIN="$HOME/Android/Sdk/ndk/${NDK_VERSION}/toolchains/llvm/prebuilt/linux-x86_64/bin"
LLVM_MINGW_TOOLCHAIN="$HOME/toolchains/llvm-mingw-${LLVM_MINGW_VERSION}-ucrt-ubuntu-22.04-x86_64/bin"

export PATH="$LLVM_MINGW_TOOLCHAIN:$PATH"

# ── Architecture-specific settings ─────────────────────────────────────────
if [ "$BUILD_ARCH" = "x86_64" ]; then
  TARGET="x86_64-linux-android28"
  WIN_ARCH="x86_64,i386"
  C_ARCH_OPTS="-march=x86-64 -mtune=generic"
  OUTPUT_DIR="$HOME/compiled-files-x86_64"
  X_LIBS=""
  XHM_FLAG="--without-xshm"
else
  TARGET="aarch64-linux-android28"
  WIN_ARCH="arm64ec,aarch64,i386"
  C_ARCH_OPTS=""
  OUTPUT_DIR="$HOME/compiled-files-aarch64"
  X_LIBS="-landroid-sysvshm"
  XHM_FLAG="--with-xshm"
fi

deps="$HOME/termuxfs/${BUILD_ARCH}/data/data/com.termux/files/usr"
RUNTIME_PATH="/data/data/com.termux/files/usr"
install_dir="$deps/../opt/wine"

# ── Compiler / linker ──────────────────────────────────────────────────────
export CC="$TOOLCHAIN/$TARGET-clang"
export AS="$CC"
export CXX="$TOOLCHAIN/$TARGET-clang++"
export AR="$TOOLCHAIN/llvm-ar"
export LD="$TOOLCHAIN/ld"
export RANLIB="$TOOLCHAIN/llvm-ranlib"
export STRIP="$TOOLCHAIN/llvm-strip"
export DLLTOOL="$LLVM_MINGW_TOOLCHAIN/llvm-dlltool"

export PKG_CONFIG_LIBDIR="$deps/lib/pkgconfig:$deps/share/pkgconfig"
export ACLOCAL_PATH="$deps/lib/aclocal:$deps/share/aclocal"
export CPPFLAGS="-I$deps/include --sysroot=$TOOLCHAIN/../sysroot"

C_OPTS="$C_ARCH_OPTS -Wno-declaration-after-statement -Wno-implicit-function-declaration -Wno-int-conversion"
export CFLAGS="$C_OPTS"
export CXXFLAGS="$C_OPTS"
export LDFLAGS="-L$deps/lib -Wl,-rpath=$RUNTIME_PATH/lib"

# ── Library flags ──────────────────────────────────────────────────────────
export FREETYPE_CFLAGS="-I$deps/include/freetype2"
export PULSE_CFLAGS="-I$deps/include/pulse"
export PULSE_LIBS="-L$deps/lib/pulseaudio -lpulse"
export SDL2_CFLAGS="-I$deps/include/SDL2"
export SDL2_LIBS="-L$deps/lib -lSDL2"
export X_CFLAGS="-I$deps/include/X11"
export X_LIBS="$X_LIBS"
export GSTREAMER_CFLAGS="-I$deps/include/gstreamer-1.0 -I$deps/include/glib-2.0 -I$deps/lib/glib-2.0/include -I$deps/glib-2.0/include -I$deps/lib/gstreamer-1.0/include"
export GSTREAMER_LIBS="-L$deps/lib -lgstgl-1.0 -lgstapp-1.0 -lgstvideo-1.0 -lgstaudio-1.0 -lglib-2.0 -lgobject-2.0 -lgio-2.0 -lgsttag-1.0 -lgstbase-1.0 -lgstreamer-1.0"
export FFMPEG_CFLAGS="-I$deps/include/libavutil -I$deps/include/libavcodec -I$deps/include/libavformat"
export FFMPEG_LIBS="-L$deps/lib -lavutil -lavcodec -lavformat"

# ── Actions ────────────────────────────────────────────────────────────────
for arg in "$@"; do

  if [ "$arg" = "--build-sysvshm" ]; then
    echo "==> Building android_sysvshm for ${BUILD_ARCH}..."
    SYSVSHM_DIR="android/android_sysvshm"
    if [ -d "$SYSVSHM_DIR" ]; then
      SYSVSHM_OUT="$SYSVSHM_DIR/build-${BUILD_ARCH}"
      mkdir -p "$SYSVSHM_OUT"
      "$TOOLCHAIN/$TARGET-clang" -Wall -std=gnu99 -shared -fPIC \
        -I"$SYSVSHM_DIR" \
        -o "$SYSVSHM_OUT/libandroid-sysvshm.so" \
        "$SYSVSHM_DIR/android_sysvshm.c"
      mkdir -p "$deps/lib"
      cp "$SYSVSHM_OUT/libandroid-sysvshm.so" "$deps/lib/"
      echo "    Copied libandroid-sysvshm.so to $deps/lib/"
    else
      echo "    WARNING: $SYSVSHM_DIR not found, skipping"
    fi
  fi

  if [ "$arg" = "--configure" ]; then
    echo "==> Configuring Wine for ${BUILD_ARCH} (archs: ${WIN_ARCH})..."
    ./configure \
      --enable-archs="$WIN_ARCH" \
      --host="$TARGET" \
      --prefix "$install_dir" \
      --bindir "$install_dir/bin" \
      --libdir "$install_dir/lib" \
      --exec-prefix "$install_dir" \
      --with-mingw=clang \
      --with-wine-tools=./wine-tools \
      --enable-win64 \
      --disable-win16 \
      --enable-nls \
      --enable-wineandroid_drv=no \
      --disable-tests \
      --with-alsa \
      --without-capi \
      --without-coreaudio \
      --without-cups \
      --without-dbus \
      --without-ffmpeg \
      --with-fontconfig \
      --with-freetype \
      --without-gcrypt \
      --without-gettext \
      --with-gettextpo=no \
      --without-gphoto \
      --with-gnutls \
      --without-gssapi \
      --with-gstreamer \
      --without-inotify \
      --without-krb5 \
      --without-netapi \
      --without-opencl \
      --with-opengl \
      --without-osmesa \
      --without-oss \
      --without-pcap \
      --without-pcsclite \
      --without-piper \
      --with-pthread \
      --with-pulse \
      --without-sane \
      --with-sdl \
      --without-udev \
      --without-unwind \
      --without-usb \
      --without-v4l2 \
      --without-vosk \
      --with-vulkan \
      --without-wayland \
      --without-xcomposite \
      --without-xcursor \
      --without-xfixes \
      --without-xinerama \
      --without-xinput \
      --without-xinput2 \
      --without-xrandr \
      --without-xrender \
      --without-xshape \
      "$XHM_FLAG" \
      --without-xxf86vm
  fi

  if [ "$arg" = "--apply-patches" ]; then
    echo "==> Applying Android patches..."
    PATCHES_DIR="android/patches"
    FAILED_PATCHES=()
    APPLIED=0

    # Common patches (both architectures)
    PATCHES=(
      # android network
      "android_network.patch"
      "dlls_nsiproxy_sys_ip_c.patch"
      # midi
      "midi_support.patch"
      # sdl
      "dlls_winebus_sys_bus_sdl_c.patch"
      # shm_utils (esync/fsync)
      "dlls_ntdll_unix_esync_c.patch"
      "dlls_ntdll_unix_fsync_c.patch"
      "server_esync_c.patch"
      "server_fsync_c.patch"
      # winex11
      "dlls_winex11_drv_x11drv_h.patch"
      "dlls_winex11_drv_bitblt_c.patch"
      "dlls_winex11_drv_desktop_c.patch"
      "dlls_winex11_drv_mouse_c.patch"
      "dlls_winex11_drv_window_c.patch"
      "dlls_winex11_drv_x11drv_main_c.patch"
      # address space
      "dlls_ntdll_unix_virtual_c.patch"
      "loader_preloader_c.patch"
      # syscall
      "dlls_ntdll_unix_signal_x86_64_c.patch"
      # pulse
      "dlls_winepulse_drv_pulse_c.patch"
      # desktop
      "programs_explorer_desktop_c.patch"
      # path
      "dlls_ntdll_unix_server_c.patch"
      # winlator
      "dlls_amd_ags_x64_unixlib_c.patch"
      "dlls_winex11_drv_opengl_c.patch"
      # shortcut
      "programs_winemenubuilder_winemenubuilder_c.patch"
      # advapi32
      "dlls_advapi32_advapi_c.patch"
      # browser
      "programs_winebrowser_makefile_in.patch"
      "programs_winebrowser_main_c.patch"
      # clipboard
      "dlls_user32_makefile_in.patch"
      "dlls_user32_clipboard_c.patch"
      "dlls_win32u_clipboard_c.patch"
    )

    # aarch64-only patches (FEX/ARM64EC support)
    if [ "$BUILD_ARCH" = "aarch64" ]; then
      PATCHES+=(
        # fexcore
        "dlls_ntdll_loader_c.patch"
        "dlls_ntdll_unix_loader_c.patch"
        "dlls_wow64_syscall_c.patch"
        "loader_wine_inf_in.patch"
        # fix build
        "programs_wineboot_wineboot_c.patch"
        "dlls_wdscore_wdscore_spec.patch"
        # bylaws: Extended State (XSTATE/YMM)
        "test-bylaws/dlls_ntdll_unwind_h.patch"
        "test-bylaws/include_winnt_h.patch"
        # bylaws: Thread Suspension
        "test-bylaws/dlls_ntdll_signal_arm64_c.patch"
        "test-bylaws/dlls_ntdll_signal_arm64ec_c.patch"
        "test-bylaws/dlls_ntdll_signal_x86_64_c.patch"
        "test-bylaws/dlls_ntdll_ntdll_spec.patch"
        "test-bylaws/dlls_ntdll_ntdll_misc_h.patch"
        "test-bylaws/dlls_wow64_process_c.patch"
        "test-bylaws/dlls_wow64_wow64_spec.patch"
        # bylaws: Process and Virtual Memory
        "test-bylaws/dlls_wow64_virtual_c.patch"
        "test-bylaws/server_process_c.patch"
        "test-bylaws/dlls_ntdll_unix_process_c.patch"
        # bylaws: Server and Threading
        "test-bylaws/server_thread_h.patch"
        "test-bylaws/server_thread_c.patch"
        "test-bylaws/dlls_ntdll_unix_thread_c.patch"
        # bylaws: Internal Headers
        "test-bylaws/include_winternl_h.patch"
      )
    fi

    for patch in "${PATCHES[@]}"; do
      PATCH_FILE="$PATCHES_DIR/$patch"
      if [ ! -f "$PATCH_FILE" ]; then
        echo "    SKIP (not found): $patch"
        FAILED_PATCHES+=("$patch (not found)")
        continue
      fi
      if git apply --check "$PATCH_FILE" 2>/dev/null; then
        git apply "$PATCH_FILE"
        echo "    OK: $patch"
        ((APPLIED++))
      else
        echo "    FAIL: $patch"
        FAILED_PATCHES+=("$patch")
      fi
    done

    echo ""
    echo "    Applied: $APPLIED patches"
    if [ ${#FAILED_PATCHES[@]} -gt 0 ]; then
      echo "    Failed:  ${#FAILED_PATCHES[@]} patches:"
      for p in "${FAILED_PATCHES[@]}"; do
        echo "      - $p"
      done
      echo ""
      echo "    WARNING: Some patches failed to apply. The build may still succeed"
      echo "    but some Android-specific features may be missing."
    fi
  fi

  if [ "$arg" = "--build" ]; then
    echo "==> Building Wine..."
    rm -rf "$OUTPUT_DIR/bin" "$OUTPUT_DIR/lib" "$OUTPUT_DIR/share" "$install_dir"
    make -j"$(nproc)"
  fi

  if [ "$arg" = "--install" ]; then
    echo "==> Installing Wine..."
    mkdir -p "$OUTPUT_DIR/bin" "$OUTPUT_DIR/lib" "$OUTPUT_DIR/share" "$install_dir"
    make install -j"$(nproc)"
    cp -r "$install_dir/bin/wine"* "$OUTPUT_DIR/bin/"
    cp -r "$install_dir/bin/reg"* "$OUTPUT_DIR/bin/"
    cp -r "$install_dir/bin/msi"* "$OUTPUT_DIR/bin/"
    cp -r "$install_dir/bin/notepad" "$OUTPUT_DIR/bin/" 2>/dev/null || true
    cp -r "$install_dir/lib/wine" "$OUTPUT_DIR/lib/"
    cp -r "$install_dir/share/wine" "$OUTPUT_DIR/share/"
  fi

done
