# Build the portable candidate

This directory contains the current contribution candidate. Use Python 3.11 or later for package assembly. The earlier builder in the parent directory reconstructs the historical accepted installation and includes libraries that PortMaster prohibits in new submissions.

Build the runtime and helpers with [the Focal toolchain](../toolchain/README.md). Arrange the outputs in a separate input directory using the paths in `payload.lock.json`: the runtime and helpers, four required native libraries under `libs.aarch64/`, and the matching ALSA configuration under `alsa/`. The lock records the tested binaries and configuration. Rebuilt inputs require an explicit lock update and relevant validation; the builder refuses unreviewed changes.

Use the collected notice directory for the same Ruffle source checkpoint. The builder verifies its Rust notices, replaces the historical native notices with the three current package notices, and flattens the result without altering the original text. The gameplay capture must be a 640×480 JPEG.

```sh
python3 build-package.py --payload /private/portable-inputs \
  --notices /private/collected-notices --screenshot /private/gameplay.jpg \
  --output /private/new-portable-preview
python3 test-package.py --preview /private/new-portable-preview \
  --output /private/new-archive-check
python3 test-launcher.py
```

The launcher fixture needs Bash and tests fake platform services without starting a game. The archive check verifies the actual ZIP, notices, native file allowlist, script modes, preparation tools and update preservation. Neither check establishes hardware support.

Input mode defaults to `auto`: Knulli uses a virtual Xbox controller through the
firmware-provided `GPTOKEYB2` command, or legacy `GPTOKEYB` when the newer command
is absent. Other firmware uses native Gilrs input. `DDD_INPUT_MODE=native` and
`DDD_INPUT_MODE=xbox360` are developer overrides for comparison runs. See
[the input investigation](INPUT-COMPATIBILITY.md) before drawing conclusions from
synthetic controller tests.

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
