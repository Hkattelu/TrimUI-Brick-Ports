# Source and licenses

This unpublished portable preview requires each player to prepare their own purchased Windows game files. It contains no game files or player saves. The offline bootstrap change still needs a PortMaster policy assessment; other firmware and devices remain untested.

The modified Ruffle runtime SHA256 is `29735ea9dc077bf8e1253da74bde1cb9c71906cde18334d5e4ef6434bfe7f3ab`, built from clean source checkpoint `ddb9a7c16792378837d95d62ee69927015882c6f`. The launcher uses firmware core libraries, SDL and EGL. WestonPack is supplied separately. The bundled native libraries are the OpenSSL 1.1 pair, zlib 1.2.11, and rebuilt ALSA 1.2.11 with its matching configuration. The original recovery helper handles invalid audio frame counts. The small Crusty `libCRU` helper changes the EGL termination return and forwards other calls through the runtime; it is not a GPU driver.

Exact sources have been collected for ALSA `1.2.11-1ubuntu0.3`, OpenSSL `1.1.1f-1ubuntu2.24`, and zlib `1:1.2.11.dfsg-2ubuntu1.5`. Component notices are retained as flat files in `licenses/`. Port helpers are MIT licensed; Ruffle's GPL license and third-party licenses are retained there as well.

A matching source archive is assembled separately with the runtime patch, locked source crates, native sources and build scripts. Before any release, establish a working link to corresponding sources alongside the binary and complete the remaining policy and device review. These materials do not establish catalogue acceptance or a blanket legal conclusion.
