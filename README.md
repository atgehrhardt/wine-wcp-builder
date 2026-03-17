# wine-wcp-builder

Automated GitHub Actions pipeline that builds [Wine](https://www.winehq.org/)
as a **WCP** (Winlator Content Package) compatible with
[GameNative](https://github.com/utkarshdalal/GameNative) and
[Winlator Bionic](https://github.com/brunodev85/winlator).

## How it works

This repo is a CI/CD wrapper around [GameNative/proton-wine](https://github.com/GameNative/proton-wine),
which is a working Proton Wine fork with Android/Bionic patches. The build produces
**both** Unix ELF libraries (for the Android host) and Windows PE DLLs, which is
required for Wine to function on Android.

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

The workflow runs daily at 06:00 UTC. When a new commit is detected on
GameNative/proton-wine, a build is triggered and a GitHub Release is
created with WCP files for both architectures.

Manual trigger: **Actions > Build Wine WCP > Run workflow**

## Directory structure

```
.github/workflows/
  build-wine.yml      ← main CI workflow

scripts/
  setup-deps.sh       ← Ubuntu 24.04 build dependencies
  pack-wcp.sh         ← WCP packaging (profile.json + tar xz)
```

The Wine source, build scripts, and Android patches all come from
[GameNative/proton-wine](https://github.com/GameNative/proton-wine)
and are cloned at build time.

## Credits

- [Wine Project](https://www.winehq.org/) – Windows compatibility layer
- [GameNative/proton-wine](https://github.com/GameNative/proton-wine) – Proton Wine for Android
- [GameNative](https://github.com/utkarshdalal/GameNative) – Wine on Android via Winlator Bionic
- [Arihany/WinlatorWCPHub](https://github.com/Arihany/WinlatorWCPHub) – WCP format reference
- [bylaws/llvm-mingw](https://github.com/bylaws/llvm-mingw) – LLVM-MinGW with ARM64EC support
- [ValveSoftware/wine](https://github.com/ValveSoftware/wine) – Proton Wine upstream
