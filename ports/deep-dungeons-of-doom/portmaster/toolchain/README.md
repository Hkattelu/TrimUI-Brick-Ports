# Focal ARM64 runtime toolchain

These scripts build a separate PortMaster compliance candidate against an isolated Ubuntu 20.04 Focal ARM64 sysroot. They do not install packages on the host or change the current Brick PortMaster Test installation, which remains the human-accepted playtest. The 58-package sysroot and pinned FreeType build completed. FreeType requires GLIBC 2.17. The full runtime build completed from the clean checkpoint. Its stripped SHA256 is `29735ea9dc077bf8e1253da74bde1cb9c71906cde18334d5e4ef6434bfe7f3ab` and it is 27,871,664 bytes. It requires at most GLIBC 2.30 and has no RPATH. On the Brick, the firmware loader ran `--version` with only Focal OpenSSL 1.1 libraries bundled. Core libraries, FreeType, ALSA and udev resolved from firmware. ALSA emitted unversioned-symbol warnings. Subsequent silent native checks reached the menu and Adventure and exercised controls and exit. Audible quality, performance and user acceptance remain unverified for this candidate. The compliance work precedes any pull request.

## Requirements and inputs

Use a Linux build environment with Python 3.9 or later, `ar`, CMake, pkg-config, Clang for bindgen, a stable Rust toolchain with the `aarch64-unknown-linux-gnu` target, and an external AArch64 GNU cross toolchain. The current bindgen include path expects GCC 13.2.1 in that toolchain. The offline Cargo build also needs the locked dependencies in its cache. Supply the clean Ruffle checkout with tracked tree `c4deba3cdc60e4889f9e14539652c2b2fdd90490`; the build script refuses a different or dirty tree. This permits reconstruction from the published upstream revision and complete patch without requiring the private commit ID.

```sh
python3 fetch-focal-sysroot.py --output /private/focal
export DDD_PM_SYSROOT=/private/focal/sysroot
export DDD_PM_TOOLCHAIN=/private/aarch64-gnu-toolchain
export DDD_PM_FREETYPE_CRATE=/private/cache/freetype-sys-0.23.0.crate
export DDD_PM_FREETYPE_WORK=/private/freetype-build
bash build-freetype.sh
export DDD_PM_SOURCE=/private/ruffle
export CARGO_TARGET_DIR=/private/ruffle-focal-target
bash build-focal-runtime.sh
```

The fetcher requires a new output directory. It downloads Ubuntu indexes and packages over HTTPS, checks index hashes against the downloaded InRelease files and package hashes against those indexes, and records the selected packages. It does not independently verify the InRelease signatures. It extracts selected files into the private sysroot without running package scripts. It supplies a `libgcc_s.so` linker alias so the GCC 13.2 toolchain does not inject a newer glibc dependency.

Focal's FreeType is too old for this build. `build-freetype.sh` verifies the pinned `freetype-sys` 0.23.0 crate and builds its FreeType 2.13.2 source into the private sysroot. Its work directory must be new. The runtime script uses the cross-linker wrappers, locked offline Cargo dependencies and two build jobs. Output stays in the supplied private target directory.

## Native audio compatibility

Firmware and Focal ALSA returned invalid available-frame counts, including about `4.23e18` frames for a 3,763-frame buffer. The recovery helper checks the buffer count, attempts one `snd_pcm_prepare` reset, and backs off after persistent invalid counts or errors. Real-preload host tests passed. Firmware ALSA still needed hundreds of resets and was rejected.

The candidate uses ALSA 1.2.11-1ubuntu0.3 rebuilt against Focal with matching configuration. Its ELF SHA256 begins `b108687`, requires at most GLIBC 2.29 and has no RPATH. The complete `build-alsa.sh` build passed with pinned hashes and patched source. The helper SHA256 begins `024b11ac` and requires at most GLIBC 2.17. Focal OpenSSL 1.1 and zlib 1.2.11 are also needed; firmware zlib lacks `inflateValidate` used by Weston PNG. `required-libraries.json` records package versions, library hashes and the failures that justify each dependency. Original package notices are retained beside it.

With the sysroot and toolchain variables above still set, build ALSA and the small helpers:

```sh
export DDD_PM_ALSA_SOURCE=/private/source-archive/native/alsa-lib_1.2.11-1ubuntu0.3
export DDD_PM_ALSA_WORK=/private/alsa-build
bash build-alsa.sh
export DDD_PM_WESTON=/private/extracted-westonpack
export DDD_PM_HELPERS=/private/helper-build
bash build-helpers.sh
```

Copy the built `libasound.so.2.0.0` as `libs.aarch64/libasound.so.2`, and copy the matching `install/usr/share/alsa` tree as `alsa/`. The helper script uses the preserved `launcher/` and `diagnostics/brick/` source paths. WestonPack supplies `libcrusty` for linking `libCRU.so` and stays separate from the player ZIP. The launcher uses the firmware's core libraries, SDL and EGL.
