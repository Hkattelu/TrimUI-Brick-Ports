# Merged Stage3D render passes — October 26, 2026

This opt-in experiment combines compatible draws into a render pass. The native
ordering fixture and ordinary-launcher smoke check pass. It is now selected for
the next untimed human playtest; user acceptance is pending.

## Source and behavior

[`merged-passes.patch`](merged-passes.patch) applies after
[`selective-buffer-barriers.patch`](selective-buffer-barriers.patch), from local
source checkpoint `76cb7013a084cfd04c722e1f6bad896b2845b039` to
`bad682ccee3dfa5d5ca50fd2e287ea45a99672a6`. These are private build checkpoints,
not upstream revision IDs. Patch SHA-256:
`bf6df934cae5929a75e06ea01489b26367284bb51b2774f86141932eb0f7ce96`.

Enable `RUFFLE_DDD_MERGE_PASSES=1` with `RUFFLE_DDD_CONSTANT_RING=1` and the
existing pipeline-cache flag. Merging includes selective buffer dependencies.
With merging unset, the prior renderer remains available for comparison.

Each queued draw retains its pipeline, bind group, constant offsets, vertex and
index buffers, index range, stencil reference and scissor. A missing scissor
resets to the full target on that draw. Clears and target changes end the pass;
conflicting buffer uploads, texture uploads, readbacks and presentation submit
earlier work first. Uploads to distinct buffers and constant-ring regions may
precede the combined pass. Retention is bounded, and ring wrap submits pending
work before reusing a region. Captured WGPU handles keep resources alive.

The ARM64 cargo check and patch reverse-application check passed. This changes
renderer scheduling only; it does not modify the game, save format, controls,
audio or ordinary launcher. See the existing Ruffle and reference-attribution
files in this directory and the adjacent AMF directory.

## Original fixture

[`BatchingProbe.as`](BatchingProbe.as) is an original finite 26-pixel-check
fixture. It uses no game assets, audio, input, saves, network or timers. It
retains the earlier snapshot, constant, same-buffer vertex/index update,
texture upload, render-target and reconfiguration checks. New checks cover
scissor reset, additive blending, texture binding, vertex binding, a clear
between draws and switching between color/texture shaders. Its rendered
composite has three rows of five cards. AA4 is requested, not proven active.

`BuildBatchingProbe.java` compiles that original source using the locally
installed FFDec library and a separately supplied playerglobal SWC. With Java
22 or later, run it in source-file mode with FFDec and its `lib/*` directory on
the classpath. Its three arguments are the source directory, a new output SWF
outside the source checkout, and the playerglobal SWC path. It refuses to
overwrite an output. No generated movie or runtime is included in the package.

## Native validation

The guarded offline ARM64 dist build passed in 259 seconds. Its stripped
runtime is 27,836,856 bytes, SHA-256
`f23f1233632b0ed13b48f17590175ddeb9df558ffa1cff832c83349aa67cd2f6`.
The 16-object ELF audit found no missing or additional dependencies.

Both 40-second fixture runs passed all 26 pixel checks:
`batch-off-XXajm9gW` and `batch-on-XXN9MGHl`. Children and parents returned 0;
the runtime was deliberately terminated with status 143 at the end of each
display interval. The parent released Weston and NX Redux returned. Captured
composites were inspected and have identical SHA-256:
`51d305fb281d169a4a7144f453c0047fdb550c24a18f06fb8958aad218eabe7b`.
Device-font warnings leave the fixture labels invisible; its colored cards and
trace-based pixel oracle remain available. This is a diagnostic limitation,
not evidence that the game's bitmap text is missing.

Two 40-second title runs used the same new binary, private movie `7406fc2c...`,
1024×768 rendering, fresh isolated profiles and silent NullAudio. Constant-ring,
selective-buffer and pipeline-cache behavior were enabled in both; only pass
merging changed. No input was injected. The first timing report was excluded.

| Recorded mean | Merging off | Merging on |
| --- | ---: | ---: |
| Stage3D command wall time per present | 18.908 ms | 12.326 ms |
| Draw phase per present | 4.095 ms | 1.391 ms |
| Present phase per present | 14.164 ms | 9.446 ms |
| Game tick per loop | 25.744 ms | 18.987 ms |
| Main loop, excluding frontend GUI phase | 33.521 ms | 26.378 ms |
| Stage3D presents sampled | 815 | 968 |
| CPU clock samples at start/end | 2.0 / 1.8 GHz | 2.0 / 1.608 GHz |

These are overlapping wall times, not displayed FPS. Changing CPU clocks and
the title-only workload prevent a precise general speedup claim. The measured
main loop was about 21% shorter. Unlike the previous barrier experiment, both
draw and presentation costs fell. This supports testing ordinary play, but does
not establish smoother combat, menu transitions or input feel.

Runs `batch-off-XXOFROCz` and `batch-on-XXiNiz2M` passed both child and parent
checks, released Weston and returned to NX. The title captures were inspected
and match exactly, SHA-256
`e4c6b8858956cfbf6d48613815055e2a170936f3aa3314459367b9b763f07d1d`.
The subsequent NX cleanup capture was also inspected. The current installed
runtime, movie, child launcher, manifest and both canonical human save files
remained unchanged. Large payloads stayed on the SD card.

Audio static and dungeon-entry selection feedback remain open issues. No
audible-quality claim follows from these silent renderer checks.

## Ordinary-launcher integration

Run `run-20261026-130933-14633` used the actual Tools entry and ordinary display
parent, the new runtime, the unchanged private movie and a separately copied
latest save. Application volume was zero, with the real audio backend still
active. It resumed the dungeon; the actual dungeon and Pause renders were
inspected. The raw 304 button opened Pause under NX's Nintendo mapping. An
earlier raw 305 press was Return, not Escape, and did not open Pause. No combat
sequence or floor progression was driven.

Holding Start and pressing Select for about 160 ms triggered the guarded exit
watcher. Child and parent returned 143, Weston was released, NX returned and
all 461 baseline manifest entries were restored. The canonical human save was
unchanged. Existing partly drawn HUD numerals also appear in the older combined
candidate's startup capture; this pass does not claim to fix that visual issue.

The smoke log records ten ALSA underrun messages and one POLLERR. Muting the
application does not bypass decoding/output work. These errors are a concrete
audio investigation lead, not proof of the cause of every reported static burst.

The subsequent untimed Tools → DDD Play Test used runtime `f23f1233...`, movie
`7406fc2c...`, original audio enabled, the short-chord helper and the canonical
human profile. Its two save files were backed up and verified unchanged during
installation, and all 461 candidate manifest entries passed. The device was
left at NX and the reservation released. The transaction restores baseline
files on exit and is one-shot; use fresh transaction paths for a future install.
The following feedback supersedes that pending assessment. Do not represent the
title timing as a combat result.

## Human combat feedback and remaining stalls

Himan reports that the merged renderer is significantly smoother and feels fairly
good, and he defeated the Monastery boss. Attacks still visibly drop frames,
especially early in play; bonus screens produce harsh static. The exit chord
eventually worked but felt frozen. This is acceptance of a substantial improvement,
not acceptance of the remaining performance or audio quality.

The completed session `run-20261026-132510-7956` contains 288 one-second runtime
reports. Excluding reports within ten seconds of the first report leaves 278
reports and 4,414 measured loop iterations. Totals are 212.133 seconds in
`player.tick`, 34.589 seconds in later movie rendering, and 37.314 seconds in
frontend GUI rendering. Tick and movie times are contained in the 247.867-second
loop measurement; GUI rendering occurs separately from that measured loop.
These are wall times, not additive CPU costs or presented frame rates.

The largest remaining tick is 281.723 ms. Several early ticks exceed 180–230 ms;
another reaches 276.349 ms near the end. The largest measured input-dispatch
operation is 5.028 ms. Dispatch cost is not button-to-screen latency: a slow tick
can delay the next input poll. The logs contain physical input edges but no
authoritative attack markers, so individual stalls cannot be labeled attacks.

Source inspection confirms that `player.tick` includes frame catch-up,
ActionScript/Starling rendering, timers, stream work and audio maintenance.
`movie_ms` measures a later render phase; a large tick does not by itself prove
an interpreter bottleneck. The active pipeline cache already includes shader
identity, compilation inputs, vertex layout and pipeline state. No cache defect
was established by this inspection, and no speculative scheduling or cache
change follows from these aggregate timings.

The next useful ordinary-play capture can enable the already-built
`RUFFLE_DDD_STAGE3D_TIMING=1` with `ddd_stage3d_timing=info`. Compare its command,
present and pipeline-preparation totals and present counts with the matching
tick intervals. This needs neither a new runtime nor a newly instrumented game
movie. Different report boundaries prevent treating near timestamps as exact
per-attack attribution. Retain normal play and the player's report of the first
problem; do not resume timed combat choreography.

The current installed candidate and quit behavior are documented in
[`FLOAT-MIX.md`](../ruffle-audio/FLOAT-MIX.md). It preserves this renderer, adds
opt-in saturated integer audio output, and keeps the candidate installed after
quitting. Himan subsequently confirmed that the static is gone, the quit chord
works and the game feels great; see that document's acceptance record. Preserve
this baseline and do not interrupt a play session merely to enable additional
measurements.
