# Source and license review

The local player preview excludes purchased game files, proprietary AIR extensions and player profiles. Each player prepares the game from their own purchased Windows copy. No Steam client is needed on the handheld. The player archive and the separate source-materials archive remain local and unpublished.

The candidate runtime was built from clean source checkpoint `ddb9a7c16792378837d95d62ee69927015882c6f`. Its ARM build and ELF audit passed. The source archive contains the complete Ruffle diff, helper sources including the EGL shutdown proxy, 17 exact native source packages and eight exact Rust crate sources. Vendored flash-lso fixtures were checked against upstream, and the Minerva fixture's ISC license is retained. Archive hashes were verified.

The notice inventory contains 971 texts for a conservative closure of 527 Rust normal and build dependencies and 21 Ubuntu binary packages, including EGL. It reports no missing notices. The closure may include dependencies not present in the final binary. Nihav crates without a declared license field use their explicit MIT COPYING text.

RealFFT 3.5.0 declared MIT but lacked a standalone license file. The collection includes the MIT license added in upstream commit `9fdcf59c60c7ecacbf75774d378a068811a2e6ea`. Comparison with 3.5.0 found no implementation change. The license file is pinned by SHA256 `080766c57f9e48f00218f4e43c7d671d4b6ffee85a39417b5ab3c916dfe29b0d`.

The packaged Ubuntu EGL library is byte-identical to the NX compatibility library. Its exact source and copyright are collected. WestonPack is supplied separately and is not included in the player archive.

Some native libraries have LGPL obligations. [MODIFYING-RUNTIME.md](MODIFYING-RUNTIME.md) describes shared-library replacement, rebuilding and publication obligations. The manifest refresh helper was tested with the real validator after library replacement and dependency addition; it preserves the original manifest, game digest and saves until the user explicitly swaps manifests.

Corresponding sources and notices must be made available alongside any eventual binary publication. These materials and checks do not constitute blanket legal approval. Verification records are in the repository's [HOST-VALIDATION.md](HOST-VALIDATION.md). Publication follows Himan's review of the draft and PortMaster maintainer review.
