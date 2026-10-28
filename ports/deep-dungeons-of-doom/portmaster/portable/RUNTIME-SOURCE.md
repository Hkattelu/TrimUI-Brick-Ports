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

`native/` retains the exact source and packaging materials for three bundled native packages: OpenSSL `1.1.1f-1ubuntu2.24`, zlib `1:1.2.11.dfsg-2ubuntu1.5`, and ALSA `1.2.11-1ubuntu0.3`. The launcher and diagnostic helper sources are under `port/launcher` and `port/diagnostics/brick`. The EGL termination helper build needs the external WestonPack; the archive does not bundle WestonPack, EGL, core system libraries or SDL.

The archive and checks support source inspection and reconstruction. They do not establish a bit-identical rebuild, audible quality, performance or acceptance on other devices. The archive remains local and unpublished. Corresponding sources must be available alongside any eventual binary release.
