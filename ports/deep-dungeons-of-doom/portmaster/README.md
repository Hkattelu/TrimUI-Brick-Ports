# PortMaster adapter and save migration

The current contribution candidate is in [`portable/`](portable/). Its [player guide](portable/PLAYER-README.md), [source and license notes](portable/SOURCE-AND-LICENSES.md), and [runtime reconstruction guide](portable/RUNTIME-SOURCE.md) describe the portable route. The local player and source archives passed their focused checks; the upstream reader and packager matched all 641 files with zero errors and one generic warning for the internal run-game.sh helper. The original Brick/NX Redux predecessor has human playability acceptance; the current offline menu change has focused agent checks. Specific audio/save-reload reports, broader firmware and resolution tests, and an offline-bootstrap policy answer remain open. Use the [community testing guide](TESTER-GUIDE.md) for volunteer setup and reports. See [the release plan](../PORTMASTER-PLAN.md).

The material below describes the earlier adapter and archive. It is retained as historical build and migration context, not instructions for the current portable package. That earlier route bundled core libraries; the portable candidate uses firmware core libraries, SDL and EGL.

## Earlier adapter and save migration

This unpublished preview targets the original TrimUI Brick with NX Redux. Himan accepted combat, audio, quick quit and menus in the earlier private playtest, then reported that the installed PortMaster Test played well, with all buttons and in-game Exit working. The obsolete playtest menu entry is archived. Its original installation and save are preserved. The uninstalled layout-only preview passed the archive checks recorded in [HOST-VALIDATION.md](HOST-VALIDATION.md). Other devices and firmware are untested. See [the release plan](../PORTMASTER-PLAN.md) for current evidence and limits.

The conventional layout places `Deep Dungeons of Doom.sh` alongside `deepdungeonsofdoom/`. PortMaster supplies the ports directory and WestonPack. The adapter accepts these pinned archives:

- Standard PortMaster WestonPack: `0bccaeebc11296bb1fe4278c9677cb82965c5a04bcd63745fa09d78228bc1a93`.
- NX WestonPack: `4c929287617b1276b5cbffcd188eea77aa979a2a84524fd222d03ed3d408c82b`.

The standard pack passed a native menu, Adventure and Exit check on the original Brick with NX Redux, including return to NX and cleanup. WestonPack is supplied separately, not bundled. The adapter retains PortMaster's message-close exit hook and does not use gptokeyb or its global process cleanup.

Run `bash "Deep Dungeons of Doom.sh" --check` in a configured PortMaster environment to check integrity without starting the game. Missing purchased game data is reported before display setup. This check does not test graphics, input, sound or save loading.

## Carry forward playtest progress

After the player exits the game, export the latest complete inactive profile, including `localhost/ddd-offline/ddd-offline.swf/`, to a separate PC directory. Keep the original installation and export until the new entry loads the expected progress. Do not use an older diagnostic snapshot.

With PowerShell 7.2 or later, from the parent source directory:

```powershell
./Import-Save.ps1 -ProfileDirectory C:/private/latest-profile `
  -PortDirectory E:/ports/deepdungeonsofdoom
```

Use the actual unpacked port location on a mounted SD card or inactive staging tree. The helper does not connect to or stop the handheld. The destination must have the current runtime and movie identities in its manifest and an absent or empty `profile/`. It refuses to overwrite existing progress.

The importer validates SOL framing and the selected save bank, creates a hash-verified backup under `save-backups/`, and stages a verified copy in `profile/`. It preserves the export and records a receipt. It does not repair malformed AMF references in an old save. A private recovered copy was tested separately; this is not an automatic repair service. Keep the source inactive throughout import. The lock prevents a new launch during import but cannot stop a game already running. The save origin remains `file:///ddd-offline/ddd-offline.swf`.

Package updates must exclude `profile/`, `save-backups/` and logs. If the destination already has progress, keep both copies and compare them before choosing which to use.

## Host checks

`python3 test-launcher.py` exercises discovery, relocation, NX script rewriting, integrity refusals, exit propagation and the PortMaster exit hook with fake platform services. It does not open a display or input device. `../tests/Test-SaveImport.ps1` checks copying, backups and refusal paths using an external inactive profile. Host checks do not establish audible behavior or a successful installation on every device.

## Build an unpublished preview

Use Python 3.11 or later and a current private installation without an imported profile. `build-preview.py` verifies the allowlisted inputs in `payload.lock.json` and excludes `ddd.swf`:

```sh
python3 build-preview.py --payload /private/install/payload \
  --notices /private/collected-notices --screenshot /private/native-gameplay.jpg \
  --output /private/new-preview
```

The output directory must be new. It contains the catalogue tree, player ZIP and checksum report. The ZIP includes an unenhanced native gameplay screenshot, but no purchased game executable content, proprietary AIR extensions, music files, profile, backup or log. Prepare game files privately using the included tools.

`fetch-notices.py --output /private/upstream-notices` retrieves 50 checksum-pinned supplemental texts. Pass that folder as `--supplement` to `collect-notices.py`. The current inventory contains 971 notice texts and reports zero missing. It includes the upstream RealFFT license that resolves the previously recorded notice gap.

`fetch-weston-egl.py --output /private/weston-egl` retrieves the exact Ubuntu EGL library and source used with the standard pack. Pass that directory with `--weston-egl` to both `collect-notices.py` and `build-source-materials.py`. `collect-native-sources.py` collects the pinned Ubuntu sources, and `collect-runtime-sources.py` collects the Ruffle diff and locked crate sources. For example:

```sh
python3 collect-runtime-sources.py --ruffle-source /private/ruffle \
  --cargo-home /private/cargo --inventory /private/collected-notices/inventory.json \
  --output /private/runtime-sources
python3 build-source-materials.py --native-sources /private/native-sources \
  --runtime-sources /private/runtime-sources --weston-egl /private/weston-egl \
  --output /private/ddd-source-materials.zip
```

The source archive is separate from the player ZIP. See [runtime source instructions](RUNTIME-SOURCE.md), [source and license review](SOURCE-AND-LICENSES.md), and [runtime modification instructions](MODIFYING-RUNTIME.md). Corresponding sources must be made available alongside any eventual binary publication.

`test-preview.py` checks an actual built ZIP using a private prepared movie, a tested Weston archive and a fresh output directory. It tests extraction, contents, modes, integrity refusals and update preservation. It does not start Ruffle or contact the handheld. The layout-only preview passed these archive checks, but retains the working runtime and dependencies and has not been installed or hardware-tested. It is not yet contribution-compliant. Neither archive has been published.
