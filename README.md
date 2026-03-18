# wine-wcp-builder

Automated GitHub Actions pipeline that builds upstream [Wine](https://www.winehq.org/)
as a **WCP** (Winlator Content Package) compatible with
[GameNative](https://github.com/utkarshdalal/GameNative) and
[Winlator Bionic](https://github.com/brunodev85/winlator).

[![Build x86_64](https://github.com/atgehrhardt/wine-wcp-builder/actions/workflows/build-wine.yml/badge.svg)](https://github.com/atgehrhardt/wine-wcp-builder/actions/workflows/build-wine.yml)
[![Build aarch64](https://github.com/atgehrhardt/wine-wcp-builder/actions/workflows/build-wine.yml/badge.svg)](https://github.com/atgehrhardt/wine-wcp-builder/actions/workflows/build-wine.yml)

## How it works

This pipeline builds Wine from [GameNative/wine](https://github.com/GameNative/wine),
which is upstream Wine with Android/Bionic patches already integrated. The build
produces **both** Unix ELF libraries (for the Android host) and Windows PE DLLs,
which is required for Wine to function on Android.

The latest branch is auto-detected from GameNative/wine's default branch on each
run, or you can specify any branch manually.

## What is a WCP?

A WCP is an `xz`-compressed tar archive containing:

```
profile.json        ← metadata (type: "Wine", wine paths, prefixPack)
bin/                ← Wine ELF executables (wine, wineserver, wineboot, etc.)
lib/wine/           ← Both Unix .so drivers and PE .dll files
share/wine/         ← NLS files, fonts
prefixPack.txz      ← Pre-built Wine prefix (registry, system initialization)
```

## What this builds

| Component | Target | Purpose |
|-----------|--------|---------|
| Wine Unix binaries | Android/Bionic (ELF) | `wine`, `wineserver`, host-side drivers |
| Wine PE DLLs (64-bit) | Windows (PE) | `kernel32.dll`, `ntdll.dll`, `d3d*`, etc. |
| Wine PE DLLs (32-bit) | Windows (PE) | WoW64 compatibility |
| Unix drivers (.so) | Android/Bionic (ELF) | X11, PulseAudio, Vulkan, GStreamer |

## Architecture targets

| Arch | Container Type | Wine archs | NDK target |
|------|---------------|------------|------------|
| x86_64 | Box64 | `x86_64,i386` | `x86_64-linux-android28` |
| aarch64 | FEX/ARM64EC | `arm64ec,aarch64,i386` | `aarch64-linux-android28` |

## Toolchain

| Tool | Version | Purpose |
|------|---------|---------|
| Android NDK | r27d | Unix/ELF cross-compilation for Android |
| bylaws/llvm-mingw | 20250920 | PE DLL cross-compilation (ARM64EC support) |
| Termux sysroot | build-20260218 | Pre-built Android libraries (freetype, vulkan, X11, etc.) |

## Automated builds

The workflow runs daily at 06:00 UTC. It auto-detects the latest branch
from GameNative/wine and builds if no matching release exists yet.

Manual trigger: **Actions > Build Wine WCP > Run workflow**

You can optionally specify a branch (e.g., `wine-11.3`) to build a specific version.

## Directory structure

```
.github/workflows/
  build-wine.yml      ← main CI workflow

scripts/
  setup-deps.sh       ← Ubuntu 24.04 build dependencies
  pack-wcp.sh         ← WCP packaging (profile.json + tar xz)
```

Wine source, build scripts, and Android patches all come from
[GameNative/wine](https://github.com/GameNative/wine) and are cloned at build time.

## Credits

- [Wine Project](https://www.winehq.org/) – Windows compatibility layer
- [GameNative/wine](https://github.com/GameNative/wine) – Upstream Wine with Android/Bionic patches
- [GameNative](https://github.com/utkarshdalal/GameNative) – Wine on Android via Winlator Bionic
- [Arihany/WinlatorWCPHub](https://github.com/Arihany/WinlatorWCPHub) – WCP format reference
- [bylaws/llvm-mingw](https://github.com/bylaws/llvm-mingw) – LLVM-MinGW with ARM64EC support
