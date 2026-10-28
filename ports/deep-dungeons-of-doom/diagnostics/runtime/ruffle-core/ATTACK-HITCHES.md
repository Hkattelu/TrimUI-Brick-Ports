# Attack hitch investigation — October 26, 2026

Himan explicitly prioritizes fixing attack frame drops before packaging. The
accepted baseline is runtime `3cd3864f...` / source `f03027e8...`: original audio
with float accumulation, the merged renderer, and the persistent quick-quit entry.
He confirmed that static and physical Start+Select exit are fixed. He subsequently
accepted combat on October 26 after the combined attack candidate: "Combat worked
fantastically." The next reported issue is skill-tree navigation; see
`../../offline/ALTAR-BUTTONS.md`. Preserve the accepted combat/audio/quit behavior
and the canonical human save. The sections below record the investigation and
its validation status at each stage.

## Reproduction and attribution

The completed human session `run-20261026-140536-18208` has a 376.178 ms maximum
tick after startup. Input edges alone do not identify individual attacks. Native
copied-save diagnostics reproduced long ticks with an active enemy. In one run,
the maximum tick was 374.701 ms while maximum pipeline preparation was 5.522 ms
and texture upload was 6.108 ms. These aggregate bounds do not isolate a cause.

A private, reversible movie probe adds three timestamps and a trace to Starling
`nextFrame`. All original instructions, constants and other method bodies remain
unchanged. Whole-file reversal and parsed-ABC identity checks pass. It separately
measures `advanceTime` and `render`; these overlap runtime tick and Stage3D work
and are neither CPU time nor presented frame rate. No game bytes are included here.

The repeatable copied-save run `batch-on-XXQWm57i` enters the next floor and sends
five right-shoulder presses three seconds apart. Source inspection confirms that
Right maps to Attack. The first press coincides with a 413.803 ms tick, including
134 ms in Starling advanceTime and 130 ms in Starling render. The longest input
dispatch in that interval is 0.775 ms. A substantial remainder follows the
completed Starling trace. Later press intervals also contain 100–127 ms advance
calls. This establishes a useful reproduction, not a fix or a causal diagnosis.

The sequence uses a fresh private copy of the latest human save, application
volume zero, a finite runtime and an owned-process watchdog. Canonical save
hashes are checked afterward. The accepted player installation was unchanged
during this diagnostic.

## Core phase timing probe

`core-timing.patch` applies after source `f03027e8a7f49a21b6c60bd5d0671c8abaa43074`.
It is diagnostic only. With `RUFFLE_DDD_CORE_TIMING=1` and
`ddd_core_timing=info`, it logs calls lasting at least 8 ms around AVM2 frame
execution, preload, post-frame callbacks, mouse/drag bookkeeping, garbage
collection, timers, stream updates and audio maintenance. Execution order and
collection policy are unchanged. Nested durations must not be added together;
unreported calls may still consume up to 8 ms each.

Source checkpoint: `040814eb8b8ee27b7d28ca51eada935c8a13ec0d`. The offline ARM64
dist build and 16-object dependency/version audit pass, with no new libraries.
Binary SHA-256: `afcc306336306dccd52cb7cb3cefb8b47582549a6d76af8b53a2a5247f99fe52`.
Patch reverse-application passes. The native run `batch-on-XXrcTyB6` identified
161.695 ms in `collect_debt` immediately after its first attack frame. Other
attack intervals contain 32–74 ms collections. Mouse/drag, post-update actions,
post-frame callbacks and timers did not exceed the probe's 8 ms logging threshold.

## Bounded cleanup candidate

`gc-slices.patch` adds an option, `RUFFLE_DDD_GC_SLICES=1`, that pays allocation
debt in batches of at most 256 collector state-machine steps with a soft 3 ms
budget per update. A single value's trace/drop cannot be interrupted. Debt above
65,536 uses normal collection to prevent indefinite deferral under heavy
allocation pressure. The default path retains the original collector behavior.

The helper uses `collect_debt_steps`, added by `gc-arena-steps.patch` to the locked
MIT-licensed gc-arena 0.7.0 sources. It retains the library's debt accounting,
tracing, sweeping and cycle transitions. To reproduce this private experiment,
copy that registry package to `core/vendor/gc-arena`, preserving its license
files, apply the collector patch there, then apply `gc-slices.patch` after the
core-timing checkpoint. The latter selects the local dependency. The vendored
files were hash-compared with the locked registry package: only `src/arena.rs`
and `src/context.rs` differ.

Source checkpoint: `d3978ccb84e10dabbbd8710caf74f0946eb56671`. Four focused tests
cover actual yielding, live-root replacement and survival, temporary-allocation
reclamation, and allocation-pressure fallback. All 32 optimized tests pass when
including the collector's 28 unchanged runtime regressions. Compile-fail UI
fixtures are outside that runtime check. The ARM64 dist build and 16-object
dependency audit pass, with no new libraries. Runtime SHA-256:
`4db2a60317634a43c81b510ec7ac6c3db6644240defcca13fbad20a2d1317875`.
Both patches pass reverse-application checks. The configured toolchain lacks
rustfmt; no formatter pass is claimed.

Two 60-second native runs used that same binary, copied save, movie probe and
five scheduled attack presses. Only cleanup slicing changed. These are short
diagnostic samples; scheduling, random effects and CPU frequency can vary.

| Measurement | Slicing off (`XXt2xKfO`) | Slicing on (`XXE2DMMt`) |
| --- | ---: | ---: |
| Largest logged GC call in first attack window | 141.115 ms | 13.875 ms |
| Largest reported tick in first attack window | 461.187 ms | 244.937 ms |
| Largest Starling advance call in that window | 140 ms | 102 ms |
| Peak resident memory sampled through process high-water mark | 214,352 KiB | 215,300 KiB |

The two-second windows begin at second-resolution input markers. Core phases
overlap; these are not additive timings or presented FPS. The enabled run paid
its remaining debt, its final reports show zero debt after each collection, and
memory stayed near the control in this short test. The pressure fallback occurred
once during startup. Both runs cleaned up successfully and the canonical save
hashes were unchanged. The accepted installed player was untouched at that stage.

This is a measured reduction in one contributor, not acceptance of attack feel.
Game-side animation updates still reached roughly 100–130 ms around attacks,
leading to the condition-error investigation below. Packaging remains deferred.

## Repeated condition errors during hits

Further private timing narrowed the remaining delay through the player's first
attack-frame callback to achievement event handling. The `beastSlayer` and
`killer` conditions repeatedly throw TypeError #1034 while coercing an old saved
value to `Vector.<*>`. Formatting and reporting the caught errors takes about
3–5 ms each, repeated across several events per hit. The raw current save already
contains references from those condition values to an unrelated plain object.
This is not evidence that every save reference is correct; the earlier LSO map
fix does not reconstruct historical data that was already written incorrectly.

A private candidate adds a type guard to the condition membership operator. Its
first argument accepts Object, checks the original vector type, and returns false
for invalid inputs before entering the unchanged membership loop. The previous
caught-error path also returned false. It neither fabricates achievement progress
nor rewrites the save. Correct vector inputs retain their original checks. The
patched movie is nine bytes larger. Whole-file reversal, original-loop identity,
parsed method/signature-only identity and stack/scope/control-flow checks pass.

The instrumented control `batch-on-XX7PGGML` and guarded candidate
`batch-on-XXERWfyT` both used the sliced-GC binary and the same copied save and
five scheduled attack inputs. The repeated coercion errors disappeared. Maximum
Starling advance times in the five attack windows were 117/93/130/142/143 ms in
the control and 38/30/36/41/35 ms with the guard. Corresponding reported tick
maxima were approximately 237/143/186/232/203 ms and 158/81/98/97/61 ms.
These short runs have the same timing and randomness limitations described above;
the extra error-attribution traces also add some overhead to the control.

Both native runs completed with child/parent exit 0 and released Weston. The
guarded run's peak resident high-water mark was 212,804 KiB, versus 215,188 KiB
in the control. A capture taken after cleanup was black, so it is not accepted
as rendered gameplay evidence. The subsequent normal-launch checks are below.
Human attack feel remains unaccepted.

## Normal launcher and save reload

The combined candidate uses runtime `4db2a603...` and the uninstrumented guarded
movie `8952b8ca...`. Core timing and private method probes are disabled. Accepted
float audio mixing, the merged renderer, button mappings and the quit helper are
retained. No new game text, visual effects or audio assets were added.

Two ordinary NX Tools launches used an isolated copy of the latest human profile
and application volume zero. Run `run-20261026-154209-852` rendered the saved
dungeon, a floor transition and an attack against a skeleton. The real 1024x768
combat screenshot and a separate settled scene were inspected. No new panels,
labels or visual effects needed cleanup. A later screenshot confirmed the NX
Tools menu after quitting. The follow-up run `run-20261026-154833-364` loaded the
same copied profile and rendered the dungeon again. Both Start+Select exits
completed in about 1.3 seconds and reported `westonMountReleased=yes`.

The copied files parsed after both runs, retaining gold 34, day 3, dungeon state
and the newly saved elapsed-time value across reload. This is focused persistence
evidence, not a guarantee for every AMF value or future dungeon. The canonical
human profile was never used by either run and its hashes stayed unchanged.
The first run logged one startup ALSA poll error, followed by continuing audio
callbacks; the reload run had no audio-stream error. Both were silent, so these
checks do not replace Himan's listening acceptance of the preceding audio fix.

The first-use rendering spike remains a known limitation. The reductions above
measure parts of attack updates, not presented FPS or physical input feel.
The 14-case condition guard regression and the 32 collector runtime tests pass.
The next gate is ordinary, untimed human play focused on attack hitching;
packaging stays deferred.

The private untimed play entry was then installed with that same runtime and
movie, the canonical human profile and normal audio volume. Installation verified
the file identities, backed up the human profile, and confirmed its hashes were
unchanged. The preceding audio/quit build remains available in the private
rollback backup; rollback must preserve any newer human save. No distributable
package was rebuilt or published. Himan's subsequent completed human session
`run-20261026-155645-11805` produced the combat acceptance noted above. Its log has
no TypeError #1034 lines and clean Weston release. Some long update intervals
remain in this mixed gameplay/menu session; those aggregates do not identify
attacks or override his physical combat feedback. Skill-tree navigation remains
unaccepted and is the next fix.
