# Build the portable candidate

This directory contains the current contribution candidate. Use Python 3.11 or later for package assembly. The earlier builder in the parent directory reconstructs the historical accepted installation and includes libraries that PortMaster prohibits in new submissions.

Build the runtime and helpers with [the Focal toolchain](../toolchain/README.md). Arrange the outputs in a separate input directory using the paths in `payload.lock.json`: the runtime and helpers, the two OpenSSL libraries under `libs/`, and the Weston-specific termination helper under `libs/crusty/`. The lock records the binary hashes. Rebuilt inputs require an explicit lock update and relevant validation; the builder refuses unreviewed changes.

Use the collected notice directory for the same Ruffle source checkpoint. The builder retains the OpenSSL notices and indexes every original Ruffle dependency notice in a single file. Supply the 640 by 480 gameplay screenshot and its sibling `cover.png` from the tester ZIP. Both images must fit the 100 KiB catalogue limit.

```sh
python3 build-package.py --payload /private/portable-inputs \
  --notices /private/collected-notices --screenshot /private/artwork/screenshot.jpg \
  --output /private/new-portable-preview
python3 test-package.py --preview /private/new-portable-preview \
  --output /private/new-archive-check
python3 test-launcher.py
python3 test-audio-env.py
```

The launcher fixture needs Bash and tests fake platform services without starting a game. The archive check verifies the actual ZIP, notices, native file allowlist, script modes, preparation tools and update preservation. Neither check establishes hardware support.

Knulli uses the firmware-provided virtual Xbox controller. Other systems keep native Gilrs input. WestonPack selects the graphics path. Ruffle uses the Crusty shutdown helper only when Weston has loaded its X11/EGL wrapper. On the ROCKNIX desktop bypass the game inherits the display session.

The game uses the firmware's ALSA library, configuration and plugins. Before Weston starts, the launcher captures any active PipeWire or PulseAudio connection. It passes that connection and explicit audio settings into the game. NX Redux supplies the zlib required by Weston libpng in the PortMaster install's own lib directory. The current runtime searches `libs/`, so a v0.1.2 overlay leaves the old ALSA and zlib outside the game's library search path.

Collect and assemble the matching native and runtime sources separately:

```sh
python3 ../collect-native-sources.py \
  --requirements-lock ../toolchain/required-libraries.json \
  --output /private/new-native-sources
python3 ../build-source-materials.py --portable \
  --native-sources /private/new-native-sources \
  --runtime-sources /private/collected-runtime-sources \
  --output /private/ddd-portable-sources.zip
```

The existing runtime source collector supplies the complete patch and locked source crates; see [runtime reconstruction](RUNTIME-SOURCE.md). Source URLs must be available alongside an eventual approved release. These builders create local archives and do not submit anything.

The launcher has no whole-package checksum gate: users can replace the runtime or dynamic libraries when rebuilding or exercising their license rights. `manifest.sha256` identifies a supported destination for the separate save-import helper; it does not prevent a modified runtime from launching. Keep private game files and profiles outside public source archives.

## Manual NX staging for development

Normal PortMaster installation handles the port layout. For a manually extracted preview staged on NX, use `bash ../../diagnostics/brick/stage-nx-preview.sh EXTRACTED_PORTS_DIR` from this directory. The helper prepares the layout expected by NX's Ports wrapper; it is a development tool, not part of the player ZIP.
