# wine-wcp-builder

Automated GitHub Actions pipeline that builds the latest stable [Wine](https://www.winehq.org/)
as a **WCP (Windows Compatibility Package)** compatible with
[GameNative](https://github.com/utkarshdalal/GameNative) and
[Winlator Bionic](https://github.com/brunodev85/winlator).

## What is a WCP?

A WCP is a `zstd`-compressed tar archive containing:

```
profile.json      ← metadata (type, version, file mappings)
system32/         ← 64-bit Windows PE DLLs
syswow64/         ← 32-bit Windows PE DLLs (WoW64)
```

The WCP is loaded by Winlator / GameNative to replace or extend the bundled Wine DLLs.

## What this builds

| Component | Source | Purpose |
|-----------|--------|---------|
| Wine PE DLLs (64-bit) | Upstream Wine stable or Winlator fork | `kernel32`, `ntdll`, `d3d*`, … |
| Wine PE DLLs (32-bit) | Same | WoW64 compatibility |

> **Not included:** ARM64 Wine host binaries (`wineserver`, loader).
> Those are bundled inside the GameNative / Winlator APK.
> Use [Box64 WCPs](https://github.com/Arihany/WinlatorWCPHub) separately.

## Build sources

### `upstream` (default)

Tracks [wine-mirror/wine](https://github.com/wine-mirror/wine) stable tags (`wine-X.0`).
[Wine Staging](https://github.com/wine-staging/wine-staging) patches are applied automatically.
Local patches from `patches/` are applied on top.

### `winlator`

Uses [brunodev85/wine-9.2-custom](https://github.com/brunodev85/wine-9.2-custom) – the Wine
fork that Winlator ships – already patched for Android/Bionic compatibility.

## Toolchain

| Tool | Version | Purpose |
|------|---------|---------|
| LLVM-MinGW | 20251104 | Windows PE cross-compilation |
| Android NDK | N/A (not needed for PE DLLs) | — |
| Wine Staging | matches Wine version | Compatibility patches |

## Automated builds

The workflow runs daily at 06:00 UTC. When a new stable Wine release is detected
(or a new commit on the Winlator fork), a build is triggered and a GitHub Release
is created with the `.wcp` file attached.

Manual trigger: **Actions → Build Wine WCP → Run workflow**

## Local patch generation

If you want to refresh the Winlator-specific patches from the fork:

```bash
bash scripts/generate-patches.sh winlator
```

This diffs `brunodev85/wine-9.2-custom` against the upstream `wine-9.2` tag and
writes the result to `patches/001-winlator-paths.patch`.

## Directory structure

```
.github/workflows/
  build-wine.yml          ← main CI workflow

scripts/
  setup-deps.sh           ← Ubuntu build dependencies
  setup-llvm-mingw.sh     ← LLVM-MinGW toolchain
  download-wine.sh        ← fetch Wine source
  apply-patches.sh        ← Wine Staging + local patches
  build-wine-tools.sh     ← native wrc/widl/winebuild
  build-wine-pe.sh        ← cross-compile PE DLLs
  pack-wcp.sh             ← assemble WCP archive
  generate-patches.sh     ← extract patches from Winlator fork

patches/
  001-winlator-paths.patch ← Winlator rootfs path adjustments
                             (generate with scripts/generate-patches.sh)
```

## Adding the WCP to GameNative / Winlator

1. Download the `.wcp` from the latest [release](../../releases).
2. Open **GameNative → Settings → WCP Manager → Add from file**.
3. Select the downloaded `.wcp`.
4. Restart the container.

## Credits

- [Wine Project](https://www.winehq.org/) – Windows compatibility layer
- [brunodev85/winlator](https://github.com/brunodev85/winlator) – Wine for Android
- [Arihany/WinlatorWCPHub](https://github.com/Arihany/WinlatorWCPHub) – WCP format reference
- [mstorsjo/llvm-mingw](https://github.com/mstorsjo/llvm-mingw) – LLVM-MinGW toolchain
- [wine-staging](https://github.com/wine-staging/wine-staging) – Wine Staging patches
