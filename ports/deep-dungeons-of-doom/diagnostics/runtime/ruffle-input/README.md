# Gamepad queue and runtime timing experiments

Earlier one-edge candidate: the helper's seven focused unit tests pass, the original timing fixture
compiles, and the complete ARM64 desktop candidate builds. It is preserved
separately from the AMF-only runtime and has not been installed or tested on the
Brick. No input-feel or performance improvement is claimed.
The AMF-only baseline has since completed the native fixture measurement below;
the queue candidate remains unselected.

An actual-game trace now confirms that a short Down press can produce repeated
menu moves. The existing one-edge queue candidate does not address all of that
behavior. A built-in NullAudio comparison reproduced the failure. A separate
runtime with bounded draining and tick/render timings has now completed a native
A/B comparison: ordinary polling produced five moves, draining three. Neither
queue policy is selected by the ordinary installation. The measured tick is
expensive, but includes game-invoked Stage3D work; it is not a CPU-only timing.
A subsequent frame probe localized most of that cost to Starling rendering,
as recorded below. It does not yet establish which renderer operation dominates.

## Earlier one-edge change

Ruffle's pinned desktop loop retrieves one Gilrs event before its player tick.
Gilrs commonly produces a button edge followed by a `ButtonChanged` event, which
the desktop ignores. The ignored event currently occupies an entire polling
iteration. The candidate scans at most 64 returned events, skips only events
that the existing conversion ignores, and stops as soon as it converts one
button press or release. All following events stay queued.

The patch adds `desktop/src/gamepad_queue.rs`, registers that module in
`desktop/src/main.rs`, and uses it in `MainWindow::about_to_wait`. The existing
button conversion, player-event handling, tick and render order remain in place.
The helper has no access to the player handler's Boolean result: a converted
edge ends the poll even if the player subsequently reports it was unhandled.
“Converted” means accepted by `gilrs_button_to_gamepad_button`, irrespective of
whether a particular command-line keyboard binding exists.

The target is upstream commit
[`159d7dbbca40bd475c8693df011b3dbf66213844`](https://github.com/ruffle-rs/ruffle/tree/159d7dbbca40bd475c8693df011b3dbf66213844).
The unmodified source identities are:

| File | SHA-256 |
| --- | --- |
| `desktop/src/app.rs` | `b23710dd69b1e009f56a7e6d75f276faf00383ad75cb32a6bdc33dcfd4ad621d` |
| `desktop/src/main.rs` | `019966ac05ab0ac1c217f3f026fd00683323040025a386a75ac4c880e7d3ff0d` |

Use `git apply --check bounded-gamepad-queue.patch` before applying it to a
separate checkout of that commit. Runtime changes retain Ruffle's MIT/Apache
licensing; the upstream license text is supplied at
[`../ruffle-amf/RUFFLE-LICENSE.md`](../ruffle-amf/RUFFLE-LICENSE.md).
The helper, tests and timing fixture are original source under this package's
MIT license. No purchased game content is included.

## Bounds and unchanged limitations

- FIFO button order and one converted transition per polling call are preserved.
  That does **not** guarantee a movie frame between a press and its release.
  Skipping an ignored-only iteration can shorten their separation. A game that
  polls held state can still miss a sufficiently short tap.
- Gilrs still performs its normal filters and automatic state updates in
  `next_event()`. Connection notifications remain ignored by Ruffle. The patch
  adds no disconnect reset, device arbitration, event timestamp retiming,
  synthesized button state, or forced frame.
- The 64-event bound limits calls to `next_event()`. Gilrs can itself discard
  raw events inside one call, so this is not a hard time or raw-event bound.
- The core tick and rendering can still dominate latency. This candidate
  addresses queue overhead, not game simulation or renderer performance.

## Mechanical checks

`gamepad_queue.rs` is exactly the module added by the patch, including its unit
tests. It has no external dependencies. Build the test executable outside this
source package:

```sh
rustc --edition 2024 --test gamepad_queue.rs -o /private/tmp/gamepad-queue-tests
/private/tmp/gamepad-queue-tests
```

All seven tests passed with Rust 1.99.1 on October 25, 2026. They cover ignored
and unsupported events, a queued short tap whose down/up remain in separate
polls, held/repeated events, opposite-direction release/press order, 64 ignored
events leaving the following edge queued, an edge at position 64 without a
65th fetch, and the empty queue. They test the actual helper, not a duplicate
implementation. The mock event converter represents the existing dispatch
boundary; it does not replace a complete runtime compilation or hardware test.

## ARM64 candidate build

The patch was applied privately after the AMF-only runtime was preserved. Its
source commit is `02b686fd66579fcfadad4e7aaeead66f26c7e9db`, based on AMF-only
commit `c0b4f51e5494cac1262181327e045779f86177e2`. With Rust 1.99.1, the existing
cross toolchain and two jobs, this command completed on October 25, 2026:

```sh
cargo build --locked --release -p ruffle_desktop --features jpegxr,fontconfig-dlopen --target aarch64-unknown-linux-gnu
```

The separate `ruffle-amf-input-candidate` executable is 44,119,032 bytes with
SHA-256 `64d983f30b9cff85cafd8db5d3b8a93796144f8bd01e0dd30835c7bb56104438`.
The ELF check covered 16 objects, found no missing dependencies or symbol
versions, and required no additional libraries. It remains dependent on the
isolated GLIBC 2.39 runtime. No RPATH/RUNPATH was present. This is the optimized
release profile, not upstream's full-LTO distribution profile.

The build and dependency checks do not execute ARM code, verify dynamic loads
or graphics, or establish input correctness on the Brick. The AMF-only binary
remains preserved for the comparison below; the candidate is not selected by
the ordinary launcher or installer.

## Original timing fixture

`InputTimingProbe.as` records keyboard transitions and counts `ENTER_FRAME`
events while each watched key is held. `INPUT_UP` includes `had_down`,
`held_frames` and `held_ms`. A matched down/up with zero held frames reveals a
tap that no frame-polled state observer saw. `INPUT_REPEAT` records duplicate
downs without resetting the hold counter. A small display shows the latest
event and Left/Right held state; it generates no input and writes no saves.

Watched keys are arrows, Enter, Space and C. The trace's frame count measures
Flash frame events, not display presentation rate or perceived input feel.
Recording an event does not by itself prove the game used it correctly.

Compile `BuildInputTimingProbe.java` with JDK 17 or later and the existing FFDec
distribution (`ffdec.jar` plus `lib/*`) on its classpath. Run the builder with
this source directory, a new private output SWF outside the checkout, and
`playerglobal32_0.swc`. It rejects existing output and output inside the source
checkout. JDK 22.0.2 and the installed FFDec produced 2,472 bytes with SHA-256
`ede4132dc9f8a01a075bf8102429444e767d0a1629f2d440c3ca6e8528a85dd0`.
Generated SWFs, class files, binaries and raw logs remain private.

## Native baseline measurement — October 25, 2026, 12:19 EDT

The Brick ran this fixture with the AMF-only dist runtime `7add99d7...` described
in [the AMF notes](../ruffle-amf/README.md). R-shoulder, D-pad-right and a longer
R-shoulder press produced six ordered key-39 edges and matching releases, with
23, 21 and 73 held `ENTER_FRAME` events. Actual evdev event-time holds were about
365, 341 and 1201 ms. Guard and timestamp work extended the nominal sleeps, so
the first two phases did not validate true 150 ms taps.

Across 74 periodic markers, the fixture executed about 60 `ENTER_FRAME` events
per second. The six raw-event-timestamp-to-Flash-trace delays were
2.333–29.438 ms. These measure software event delivery and Flash execution,
not presented FPS, physical input feel or DDD responsiveness. Child and parent
returned 0, the display mount was released, and NX Redux returned. The user
reported a black upper third and white lower area during the fixture, then
confirmed the physical screen showed NX afterward. The fixture's display
remains unresolved and the traces do not establish visual success.

## Device measurements

### Actual DDD menu trace — October 25, 2026, 13:56 EDT

A temporary, reversible trace in ButtonMenu recorded one fresh Down followed by
four repeats: selection `0 → 1 → 2 → 0 → 1 → 2`. The native press lasted
161.028 ms. The Gilrs `Original event` read trace recorded its press 355.946 ms
after the embedded raw-event timestamp and its release 1324.652 ms after that
edge's timestamp. Those reads were 1129.734 ms apart. These are raw-to-Gilrs-read
measurements, not timestamps after conversion or dispatch to the player. The
first repeat followed the fresh move by only 5.544 ms of wall time as the game's
fixed-step loop caught up.

This explains how a short tap can cycle through multiple menu options. It does
not establish the exact sequence of the earlier untraced run. The early captured
frame still showed Resume; the trace establishes logical selection changes,
not the time those changes reached the physical display. The separate unsigned
[Up-wrap correction](../../offline/MENU-UP-WRAP.md) does not fix these repeats.

The existing candidate skips ignored events but still dispatches at most one
converted edge before a tick. It can remove an ignored-event polling delay,
but cannot prevent the repeats already generated during the first catch-up.
These findings motivated the separate bounded-drain/timing experiment recorded
below. No new runtime policy has been selected for the ordinary installation.

The two-minute diagnostic ended through its owned deadline, returned status 130
in child and parent, released the Weston mount, restored the exact ordinary
movie/launcher/manifest on-device, and returned to NX. Audio settings were unchanged.

### Built-in NullAudio comparison — October 25, 2026, 14:35 EDT

Private run `run-20261025-143538-9760` used the same AMF-only dist runtime and
menu trace with a run-local ALSA configuration naming a nonexistent hardware
card. The log confirmed `Unable to create audio device: Failed to get default
output config`, retaining Ruffle's built-in NullAudioBackend. This differs from
an active ALSA `type null` stream. The recovery-shim preload, mappings, profile,
window and tracing options stayed unchanged.

The movie also needed the existing five-byte silent-logo patch: its startup
deadline changed from 500 to 2660 ms, then it returned before creating the logo
sound. Otherwise the original sound-position gate could stall under NullAudio.
The warmed menu trace was unchanged. This startup difference prevents describing
the whole run as a single-variable movie comparison.

The Down hold was 160.685 ms. Its raw-to-Gilrs-read delays were 269.123 ms for
press and 1322.438 ms for release, with a 1214.000 ms read span. The menu again
recorded one fresh move and four repeats: `0 → 1 → 2 → 0 → 1 → 2`. The final
captured Pause frame highlighted Exit Dungeon. Disabling audio-device
initialization therefore did not resolve the observed selection failure; this
does not establish that audio has no performance cost.

The 120-second deadline returned 130 in child and parent, released the Weston
mount and owned processes/sockets, restored the exact ordinary movie, launcher
and manifest, passed all 461 manifest checks, and returned to NX. Audio listening
remains deferred. These traces and captures do not measure physical input feel,
display latency or presented FPS.

### Bounded-drain/timing source and build

[`runtime-timing-and-gamepad-drain.patch`](runtime-timing-and-gamepad-drain.patch)
is the exact four-file change from AMF-only source
`c0b4f51e5494cac1262181327e045779f86177e2` to private diagnostic checkpoint
`9571647dc413cd17ca9e519c8a1570197582a59a`. It is separate from the earlier
one-edge queue patch: apply it to the AMF-only base, not on top of that experiment.
Its SHA-256 is
`48b45b16b986dacbf2c6257089813c148eff963108cc7ca7adc4161d0f88071e`.
It changes `desktop/src/app.rs` and `main.rs`, and adds `gamepad_drain.rs` and
`runtime_timing.rs`, including seven drain and three timing unit tests. Those
focused tests and the ARM64 desktop integration check passed. The patch contains
runtime source only; no game movie, decompiled game code or binary is included.
The Ruffle license reference above also applies to this patch.

Both controls default off; only the literal value `1` enables them:

- `RUFFLE_DDD_DRAIN_GAMEPAD=1` dispatches up to 64 returned Gilrs events FIFO
  before the tick, including every converted press/release. Ignored or unhandled
  events do not stop it. Desktop rendering is deferred until after the batch
  and tick; core event handling still runs for each converted edge. With the flag
  absent, ordinary one-event/render/tick ordering remains. The bound is neither
  a raw-kernel-event limit nor a wall-time limit, and does not guarantee a game
  frame between edges or preserve multiple frame-polled taps as separate actions.
- `RUFFLE_DDD_TIMING=1` measures poll gaps, polling, core event dispatch, tick,
  movie rendering, GUI rendering and the containing loop. Reports require
  `ddd_runtime_timing=info` in `RUST_LOG`. Without the flag, diagnostic timing
  reads and report allocation are disabled. Phase durations overlap and must
  not be summed; GUI timing includes acquisition/submission/presentation, not
  completion of GPU work.

The clean diagnostic checkpoint built with Rust 1.99.1, two jobs, offline locked
dependencies and the `dist` profile (fat LTO, one codegen unit):

```sh
cargo build --locked --offline --profile dist -p ruffle_desktop --features jpegxr,fontconfig-dlopen --target aarch64-unknown-linux-gnu
```

The copied/stripped executable is 27,794,104 bytes, SHA-256
`0bcd78d0798778097b5e3648bf16cae23b006a16e23d094e316e2270f67a7625`.
Its 16-object ELF audit found no missing library/version requirements, no
RPATH/RUNPATH and no added libraries beyond the existing isolated runtime.
The original AMF-only dist executable `7add99d7...` remains the installer's and
ordinary launcher's selected runtime.

### Same-binary native A/B — October 25, 2026

Both 120-second trials used the diagnostic binary above, the same private
silent-logo menu-trace movie `7c59b022...`, built-in NullAudio, mappings, window
and persistent test profile. The five-byte startup difference described above
was present in both movies. Both enabled timing and the same AVM/Gilrs/adapter
log targets; the only launcher difference was the drain flag, absent in the
baseline and `1` in the experiment.

The short Down press produced five menu moves in the baseline,
`0 → 1 → 2 → 0 → 1 → 2`. Draining produced three, `0 → 1 → 2 → 0`:
one fresh move and two repeats. The drain run read the press before its raw
release had occurred, so the release was not yet available to that drain;
catch-up game steps could repeat the held input before the next poll. This
single comparison does not establish a reliable improvement. Bounded draining
is insufficient and remains unselected. Gilrs `Original event` traces mark reads,
not post-conversion or post-dispatch timestamps.

In baseline windows without input events, the mean tick wall time was 710.027 ms
in the warmed sewer (30 samples across 15 complete reports) and 539.006 ms in
Pause (28 samples across 14 complete reports). Mean poll gaps were 726.358 and
554.186 ms; movie-render calls averaged 8.615 and 6.864 ms, and GUI calls 9.420
and 9.374 ms. Tick dominated the measured loop. It includes movie execution and
Stage3D work invoked by that execution, so these timings do not isolate CPU-only
AVM cost. These no-input windows contain no dispatch samples. They do not
measure GPU completion, presented FPS, physical input latency or control feel.

Both trials ended at the owned deadline with status 130 in child and parent,
released the Weston mount and owned session resources, and restored the exact
ordinary runtime, movie, child launcher and manifest (`7add99d7...`,
`6965...`, `dab7...`, `3f19...`). All 461 manifest checks passed after each
restoration and NX returned. Private logs, movies, profiles and binaries remain
outside this source package. Audio listening remains deferred.

### Starling frame-cost probe — October 25, 2026, 15:29 EDT

Private run `run-20261025-152948-24165` retained diagnostic runtime `0bcd78d0...`,
bounded draining, timing, NullAudio, mappings and the persistent test profile.
Only the private movie changed from the previous drain trial. A reversible
method-809 probe timed the existing `advanceTime` and `render` calls without
changing their order, the original delta calculation or the last-frame timestamp.
It logged once per completed Starling frame. Exact byte reversal, full ABC
comparison, stack/scope/local validation, actual decompilation and an independent
review passed before execution. The instrumented movie remains private.

The root reviewer inspected the rendered sewer and Pause/Resume selection.
Conservative settled windows contain no input events or dispatch samples:

| State | Complete reports / core ticks / Starling frames | Mean advanceTime | Mean render | Mean core tick |
| --- | --- | --- | --- | --- |
| Sewer, 19:30:34.685–19:30:58.924 UTC | 17 / 34 / 34 | 23.676 ms | 668.500 ms | 694.598 ms |
| Pause, 19:31:16.080–19:31:42.520 UTC | 24 / 48 / 48 | 5.083 ms | 526.063 ms | 534.116 ms |

Rendering accounted for 96.58% and 99.04% of the summed measured call durations.
The outer-frame counts match core-tick counts in these windows. The costly path
is therefore Starling rendering, including synchronous Stage3D calls, rather
than the measured game-update call. This does not separate ActionScript draw
traversal from backend/driver work or measure GPU completion. Timer/log overhead
is included; original deltas and call counts are not presented FPS. The probe
does not count inner fixed-step simulation iterations or establish input feel.

The focused next candidate is an opt-in renderer change, preserving the AMF fix
and current shader-error behavior. No renderer optimization has been selected
or demonstrated on the Brick at this checkpoint. The 120-second run returned
130 in game and parent, released its owned display resources and restored the
exact ordinary four-file set. All 461 restored manifest entries passed and NX
returned. Audio listening remains deferred.

### Remaining input checks

A selected correction must address the expensive tick and repeat behavior in
the actual game. For any further runtime comparison, preserve the same options,
an owned test session and guarded input. Test several short durations
and offsets relative to the fixture frames, a one-second hold, and immediate
Left-to-Right reversal. Compare injected down/up counts with trace counts and
confirm every release clears state. Preserve the exact pulse durations and
check for repeats, dropped transitions and zero-frame holds; do not hide a
failed case by only reporting longer taps.

After the fixture, exercise the actual game's menu selection and attack/defend
with the same mappings and inspect the rendered result. Repeat under a relevant
loaded-game condition, because a trivial fixture does not reproduce DDD's
simulation cost. Physical input feel remains a human check. The initial
acceptance gate is preserved event order and no lost/stuck keys; any latency
claim additionally needs comparable measurements.
