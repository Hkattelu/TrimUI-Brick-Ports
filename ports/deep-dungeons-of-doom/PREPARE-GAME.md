# Prepare a private game candidate

`Prepare-GameCandidate.ps1` reproduces the current private movie from a locally
installed, purchased Windows copy of Deep Dungeons of Doom. It runs pinned helpers
and verifies every intermediate result. It does not prepare a runtime, contact
the Brick, launch Steam or modify the original game.

Use Windows and PowerShell 7.2 or later. The original SWF, manifest at
`META-INF/AIR/application.xml` and declared AIR extension libraries are required.
The supported main SWF has SHA-256
`595142a1136f286e1d76913722b46bf7dd207a5a326fe174170feab90325b4e0`.
Other revisions are refused before an output directory is created.

Choose a new output directory outside the game installation and source package:

```powershell
./Prepare-GameCandidate.ps1 `
  -GameFile 'C:/Program Files (x86)/Steam/steamapps/common/deepdungeonsofdoom/ddd-0.1-SNAPSHOT.swf' `
  -OutputDirectory 'C:/private-tests/ddd-stash'
```

The parent directory must exist; the output directory must not. Linked paths are
refused. Preparation never replaces or deletes existing files. If a step fails,
retain that new directory for diagnosis and use another output path on retry.

The output contains `ddd.swf`, `preparation.json`, `SHA256SUMS` and intermediate
movies/reports under `steps/`. **Keep the entire output private:** it contains
purchased game content and extension bytecode. Only preparation sources and
documentation belong in the shareable archive.

## Available variants

| `-Candidate` | Result SHA-256 | Status |
| --- | --- | --- |
| `OfflineMenus` (default) | `a2700be5d4bdc8c7cd2a9443024af2795b4fd40bc13eede4ce3abef25c876d44` | Adds disabled Trophies/Hi-score buttons to StashActions. Muted Brick menu checks passed on October 28. Human feedback on this small menu change is pending. |
| `StashActions` | `df2b4af61a382e112eab5fd7e02db17f562325068621b6bb598fa0e9e9029804` | Previous movie used in the accepted portable build. Retains the original active-looking Trophies/Hi-score buttons despite unavailable Steam services. |
| `AcceptedMenus` | `0dbeb95bea2ad0d64cfb6617a79ff210c15a13183d17e05fc88bcde573fe0b91` | Pre-stash comparison build with accepted attack-condition and skill-tree adaptations. Used with runtime `4db2a603...` in accepted human play; not exhaustive game coverage. |
| `Legacy` | `7406fc2cb24c5b2faf218797b1d6fcc6690fb8522c6f0bc7daf63853ad141d05` | Historical baseline retained for the existing private-install preparer and comparisons. Predates accepted combat/menu fixes. |

The report records the selected variant and its validation limits. `OfflineMenus`
became the default after the October 28 [offline menu checks](diagnostics/offline/OFFLINE-EXTRAS.md). See
[menu coverage](diagnostics/offline/MENU-COVERAGE.md) and
[stash candidate checks](diagnostics/offline/STASH-ACTIONS.md).

## Runtime and installation boundary

Movie preparation alone is not a playable installation. Use the
[portable PortMaster candidate](portmaster/portable/README.md) for `OfflineMenus`,
with runtime `29735ea9...`. The historical
[private-install preparer](PRIVATE-INSTALL.md) supports `StashActions` and `AcceptedMenus`
with their exact accepted runtime and helpers, preserving the renderer, float
audio mixing, sliced garbage collection, quick quit and normal audio output.
Legacy remains an explicit historical comparison. A newly prepared install still
needs device validation; the source archive is not a PortMaster release.

The historical private-install runtime is
`4db2a60317634a43c81b510ec7ac6c3db6644240defcca13fbad20a2d1317875`.
Its performance evidence is in
[ATTACK-HITCHES.md](diagnostics/runtime/ruffle-core/ATTACK-HITCHES.md).
Remaining release work is in [PORTMASTER-PLAN.md](PORTMASTER-PLAN.md).
