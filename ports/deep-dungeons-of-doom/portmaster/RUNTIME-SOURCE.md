# Reconstruct the save-writer and Exit runtime source

The source-materials archive accompanies the local preview. It is separate from
the player ZIP and contains no purchased game movie or player profile.

## Ruffle

Start with a clean checkout of the official
[Ruffle repository](https://github.com/ruffle-rs/ruffle) at upstream commit
`159d7dbbca40bd475c8693df011b3dbf66213844`. Apply
`runtime/ruffle-ddd-complete.patch` from the source-materials archive:

```sh
git checkout --detach 159d7dbbca40bd475c8693df011b3dbf66213844
git apply --check /path/to/runtime/ruffle-ddd-complete.patch
git apply /path/to/runtime/ruffle-ddd-complete.patch
```

The complete diff includes the GC fork, save compatibility, renderer, audio,
controller and AIR Exit changes. Its local source commit is
`ddb9a7c16792378837d95d62ee69927015882c6f`; the tracked tree identity is
`c4deba3cdc60e4889f9e14539652c2b2fdd90490`. The source collector checked the reverse
patch against that clean committed index, including files omitted by the sparse
working checkout. This is a source correspondence check, not a new clean build.
The ARM64 build succeeded and passed its dynamic dependency audit. A copied
profile completed native save, menu Exit and reload checks on the original Brick.
This candidate has not replaced the human playtest installation.

The complete patch includes the modified `flash-lso` source and its original
regression tests. Its public upstream fixtures are checked against commit
`61b717248aae853a4f5d8a103eba704268d286c8` before inclusion. Binary fixtures must
match exactly; the provenance separately records Git's CRLF normalization of
Rust text. This exception does not admit private game files or player saves.
The fixtures identified in the dependency's `tests/README.md` come from Minerva;
their ISC notice and pinned upstream source are retained separately in the archive.

The build used Rust/Cargo 1.99.1, an AArch64 GNU cross toolchain based on
GCC 13.2.1, the pinned `Cargo.lock`, and:

```sh
cargo build --locked --offline --profile dist -p ruffle_desktop \
  --features jpegxr,fontconfig-dlopen --target aarch64-unknown-linux-gnu
```

The `dist` profile uses fat LTO and one codegen unit. Set the AArch64 linker, C/C++
compiler, archiver, pkg-config sysroot and libclang paths for your environment.
The build ran two jobs. Its exact runtime/dependency identities are in
the preparation reports and `build-provenance.json`. Different toolchains may
produce different bytes. Do not claim a rebuilt binary is the accepted binary
without comparing it and testing the changed artifact.

The source-materials archive includes exact, Cargo.lock-verified source crates
for the MPL dependencies and default fonts. It also retains RealFFT 3.5.0's source.
The notice fetcher supplies the MIT notice added upstream for 3.5.1, whose
implementation is unchanged from 3.5.0. Other
dependencies can be fetched from the locked Cargo sources before an offline
build; no game data is needed to build Ruffle. The full notice inventory includes
normal/build dependencies and may overinclude workspace feature unions.

## Native libraries and helpers

`native/sources.json` identifies the 16 source packages behind the 20 distributed
Ubuntu binary packages. The archive contains their exact original source tarballs,
Debian/Ubuntu packaging patches and `.dsc` files. SHA256 values match official
Ubuntu source indexes, whose compressed hashes match HTTPS-fetched InRelease
records. OpenPGP signatures were not independently verified. The archive preserves
those index records for review.
`weston-egl/` adds the seventeenth source package, libglvnd, for the EGL library
needed by the standard WestonPack. It includes the exact Ubuntu source and
packaging archives, copyright notice and index verification records.

The original launcher helpers are included under `helpers/`, with their MIT
license. They are built for AArch64: the exit watcher and log drain are C programs,
and the ALSA recovery shim is a shared object linked with `libdl`. The EGL shutdown
proxy source and build script are included too; it links to the pinned Crusty
library supplied separately by WestonPack. Their detailed
source comments and the public diagnostics explain their behavior. Build with
the same cross sysroot and keep the resulting dependency audit alongside them.

This source bundle supports inspection and rebuilding. It does not establish
public-release permission or a bit-for-bit rebuild. Focused native startup,
save/reload and Exit checks passed on the original Brick with NX Redux, including
the standard catalogue WestonPack. Audio quality and broader device support are
separate validation questions. See `WESTON-COMPATIBILITY.md` for that test's scope.
