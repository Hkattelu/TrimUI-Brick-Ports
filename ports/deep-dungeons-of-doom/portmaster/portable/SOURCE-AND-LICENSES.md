# Sources and licenses

The player supplies the Windows Steam game files. The two catalogue images come from gameplay and title captures. Deep Dungeons of Doom and its artwork belong to their respective owners.

The corresponding source archive is `ddd-portable-sources.zip`. It contains the modified Ruffle sources as a patch against the revision identified in `RUNTIME-SOURCE.md`, locked dependencies, native helpers and the source materials for the bundled OpenSSL 1.1 libraries. PortMaster supplies WestonPack separately. The firmware supplies ALSA, zlib and the graphics driver.

The flat `licenses/` directory includes the full Ruffle and dependency notices, OpenSSL notices and the port helpers' MIT license. `license-inventory.json` identifies the component, offset, length and SHA-256 of each original notice within the combined text.
