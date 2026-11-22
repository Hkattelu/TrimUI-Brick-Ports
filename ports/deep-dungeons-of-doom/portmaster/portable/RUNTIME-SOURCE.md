# Reconstruct the portable runtime

The source archive is separate from the player ZIP and contains no purchased game movie or player profile. It preserves the project layout under `port/`, including `port/portmaster/toolchain`, `port/launcher` and `port/diagnostics/brick`. Runtime and native source materials remain under `runtime/` and `native/`.

## Ruffle

Start with a clean checkout of [Ruffle](https://github.com/ruffle-rs/ruffle) at upstream commit `159d7dbbca40bd475c8693df011b3dbf66213844`, then apply the complete patch from the source archive:

```sh
git checkout --detach 159d7dbbca40bd475c8693df011b3dbf66213844
git apply --check /path/to/runtime/ruffle-ddd-complete.patch
git apply /path/to/runtime/ruffle-ddd-complete.patch
git add -A
git write-tree
git commit -m 'Apply DDD compatibility changes'
```

Before committing, check that `git write-tree` prints `c4deba3cdc60e4889f9e14539652c2b2fdd90490`. These commands assume a dedicated clean checkout. The build script accepts a clean checkout with that tree; it does not require the private commit identity. The archive retains the complete patch, locked runtime crate sources and fixture provenance. See `port/portmaster/toolchain/README.md` for the Focal ARM64 sysroot, FreeType, external Rust and GNU toolchains, and build commands. Obtain locked Cargo dependencies before the offline build.

## Native sources and helpers

`native/` contains the source and Ubuntu packaging for the bundled OpenSSL 1.1 pair (1.1.1f-1ubuntu2.24). The port helper sources are under `port/launcher` and `port/diagnostics/brick`. Building the EGL termination helper requires the separately installed WestonPack.

## First-launch helper

The helper sources and copy-only recipe are in `port/portmaster/portable/preparation/`.
Build `ddd-prepare` using its `build.sh` with the same Focal toolchain variables.
It links OpenSSL 1.1 and the system zlib ABI. Players supply their Windows
Steam game files, and preparation runs on the handheld without PowerShell.

The archive and checks support source inspection and reconstruction. They do not establish a bit-identical runtime rebuild, audible quality, performance or acceptance on other devices. Corresponding sources must remain available alongside the binary release.
