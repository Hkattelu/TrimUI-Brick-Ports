# Prepare a private installation

`Prepare-PrivateInstall.ps1` assembles a new private tree from an owned, prepared
DDD movie, a verified ARM64 runtime, its dependency report, portable libraries
and the compiled launcher helpers. It never contacts the Brick or changes an
existing installation. Its output contains purchased game content and must stay
private.

## Current build

The preparer accepts both `StashActions` (`df2b4af6...`, the previous movie-preparation
output) and the previous `AcceptedMenus` (`0dbeb95b...`). Both require the exact
accepted runtime `4db2a603...`, source checkpoint `d3978ccb...`, and the tested
quick-quit, log-drain and ALSA recovery helpers. The build report must identify the
same runtime and a complete dependency graph.

The generated child launcher enables the accepted pipeline cache, constant ring,
selective barriers, merged render passes, float audio mixing, bounded garbage
collection and controller draining. Normal firmware audio routing and application
volume 1 are preserved. Diagnostic timing and alternative renderer experiments
are disabled. It leaves the device's saved volume settings alone.

```powershell
./Prepare-PrivateInstall.ps1 `
  -PrivateGameFile C:/private/game-candidate/ddd.swf `
  -RuntimeFile C:/private/gc-build/ruffle-ddd-gc-slices-dist `
  -RuntimeDependencyReport C:/private/gc-build/dependency-report.json `
  -PortableDirectory C:/private/portable `
  -ExitWatcherFile C:/private/ddd-exit-watch `
  -LogDrainFile C:/private/ddd-log-drain `
  -AudioRecoveryFile C:/private/libddd_alsa_poll_recovery.so `
  -OutputDirectory C:/private/ddd-install-candidate
```

The output directory must be new and outside the source checkout/package and
input profile. Unknown game revisions, mismatched runtime/helper builds, linked
paths, changed dependencies and incomplete or ambiguous reports are refused.
The ELF symbol-version audit belongs to the runtime build; the preparer verifies
its identities and coverage rather than substituting a JSON report for that audit.

## Saves

Optionally pass `-ProfileDirectory` for a complete, inactive profile containing
`localhost/ddd-offline/ddd-offline.swf/`. The supported files are `saveSlotData.sol`
and `userdata.sol`/`userdata1.sol`; bank zero has no numeric suffix. The selector
and its selected bank are required. SOL headers, names, lengths and the bank
selector are validated. Copies are hash-verified and the original
profile remains unchanged. Omitting the argument creates an empty profile.

Keep the movie's save origin `file:///ddd-offline/ddd-offline.swf` unchanged when
moving the installation. A backup from before tonight's play is not a substitute
for the player's latest save. Do not replace an existing profile during install
or update, and do not copy while the game is running.

## Output and validation boundary

- `payload/` contains the runtime, movie, launcher, portable dependencies and
  immutable-file manifest. `profile/` is separate from that manifest.
- `menu/Deep Dungeons of Doom.sh` is the existing NX Ports entry.
- `preparation.json` records the exact identities, selected settings and explicit
  uninstalled/hardware-unvalidated status.

The legacy menu entry targets `/mnt/SDCARD/.ports/deep-dungeons-of-doom`. The core
launcher now resolves its directory from its own location. The separate
[PortMaster adapter](portmaster/README.md) supplies platform discovery and the
Weston runtime path for the conventional `deepdungeonsofdoom` layout. Do not copy
a private output into a public release or overwrite the working DDD Play Test
installation to test it.

For migration into a new unpacked port, use `Import-Save.ps1` with a fresh,
inactive exported profile and `-PortDirectory` pointing to `deepdungeonsofdoom`.
It refuses an existing populated profile, retains a verified backup, and stages
the full selected bank before moving it into place. Read the adapter instructions
for the exact command and native reload boundary.

The original runtime/movie behavior has native and human-play evidence, described
in [attack fixes](diagnostics/runtime/ruffle-core/ATTACK-HITCHES.md) and
[stash checks](diagnostics/offline/STASH-ACTIONS.md). A newly prepared installation
still needs an ordinary launch, quit and save/reload check on the target device.
The preparer does not certify full-game or cross-firmware compatibility.

`tests/Test-PrivateInstall.ps1` takes an external JSON file containing the input
arguments above (plus an inactive copied profile), and a new private output path.
It checks the actual assembled manifest, save copies, accepted settings, rejection
of wrong runtime/helper/provenance and duplicate providers, and input preservation.
It never mounts a display or contacts a device.

## Historical comparisons

The recognized legacy movie `7406fc2c...` still requires runtime `b381ea22...` and
its old silent pipeline-cache preset. Earlier recognized probes retain their
historical settings. These options exist for diagnosis; use the current movie
and accepted runtime for packaging work. The former silent preset is no longer
the only supported integration.
