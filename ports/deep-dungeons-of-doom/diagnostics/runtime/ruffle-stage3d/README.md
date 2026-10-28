# Stage3D pipeline-cache experiment

This opt-in candidate targets the rendering cost measured in the
[native frame probe](../ruffle-input/README.md#starling-frame-cost-probe--october-25-2026-1529-edt).
Source review, an ARM64 integration check, the full build and its dependency
audit have passed. An initial native trial rendered correctly and recorded one
menu move from a short Down tap. A follow-up with the same binary and caching
disabled reproduced long render times, while clock limits varied during the
run. The evidence supports further button validation of this candidate without
claiming a precise speedup. The ordinary runtime remains selected.

## Source and application

[`pipeline-cache.patch`](pipeline-cache.patch) changes only
`render/wgpu/src/context3d/current_pipeline.rs`. It is the exact change from
private diagnostic source `9571647dc413cd17ca9e519c8a1570197582a59a` to
`eb3a0eba439b5872337a2c2784a598e5cd0b9f61`. The patch SHA-256 is
`eaddf2725692ce991552d9d73282ba3967ae35a92a2b999a8a424a8fe61c7128`.
Its base preserves the AMF reference fix and the separate input/timing experiment
on upstream Ruffle `159d7dbbca40bd475c8693df011b3dbf66213844`.

Apply the documented [AMF fix](../ruffle-amf/README.md) and
[input/timing patch](../ruffle-input/README.md#bounded-draintiming-source-and-build)
first, then run `git apply --check pipeline-cache.patch` before application.
Keep a recoverable checkout and earlier runtime; the private commit identifiers
record local source history and are not advertised as upstream commits.

The design was informed by the pipeline-cache portion of
[Fancy Pants patch 0002](https://github.com/crxssrazr93/fancypants-portmaster/blob/86a641c2aa6a3901efddcaa492b37e8f3e27ce13/build/ruffle-patches/0002-PortMaster-port-Stage3D-batching-pipeline-bind-group.patch).
It is adapted to this newer renderer and its fallible shader compilation.
Ruffle's [MIT/Apache license notices](../ruffle-amf/RUFFLE-LICENSE.md) apply.
No game movie, assets, decompiled game code or compiled runtime is included.

## Behavior

Only the literal environment value `RUFFLE_DDD_STAGE3D_PIPELINE_CACHE=1` enables
the cache when a context is created. The default path retains the existing
shader compilation, pipeline-layout, bind-group and pipeline creation order.

The cache holds up to 256 completed pipelines per context. The key covers shader
identity and compile data, canonical grouped vertex layouts, stride and attribute
locations, culling, depth/stencil state, blending, color mask, target format and
sample count. Each entry retains shader ownership and its exact bind-group
layout. Every hit creates a fresh bind group from current textures, samplers and
uniform buffers. The entry bound is not a hard GPU-memory bound.

Failed shader compilations do not enter the cache. Key construction avoids
premature bounds or stride-overflow failures; a miss performs the original
validation after successful shader compilation. The original invalid-stride
behavior is preserved, not independently repaired here.

Draw submission, texture uploads, shader-cache size and the frontend are unchanged.
Batching is deferred because `drawToBitmapData` can read the back buffer before
`present`, requiring an additional flush boundary.

## Checks and limits

Two source reviews covered the full key, layout/shader lifetime, eviction and
error ordering. The exact final source passed the offline ARM64 desktop check
with Rust 1.99.1, two jobs and the existing toolchain:

```sh
cargo check --locked --offline --profile dist -p ruffle_desktop --features jpegxr,fontconfig-dlopen --target aarch64-unknown-linux-gnu
```

The clean checkpoint subsequently built with the same options using
`cargo build` instead of `cargo check`. The dist profile uses fat LTO and one
codegen unit. The stripped ARM64 executable is 27,805,624 bytes, SHA-256
`b381ea2275a9b9b720115cf7620965036227001e2fbc2761bc9084700f8ffd70`.
The 16-object ELF audit found no missing library or symbol-version requirements,
no RPATH/RUNPATH and no added libraries beyond the existing isolated runtime.

### Initial native trial

Run `run-20261025-155235-20296` enabled the cache, bounded input draining and
phase timing. It retained the earlier private frame-probe movie, NullAudio,
controller mapping, resolution and persistent profile. The reviewer inspected
the rendered sewer, Pause with Resume selected, and the result after Down.

| State | Starling frames / core ticks | Mean advanceTime | Mean render |
| --- | --- | --- | --- |
| Sewer | 496 / 496 | 6.409 ms | 74.738 ms |
| Pause | 175 / 175 | 1.589 ms | 54.423 ms |

These settled windows contain no input events. The earlier probe recorded
render means of 668.500 ms and 526.063 ms. However, the new trial sampled a
2.0 GHz CPU clock versus the earlier 1.8 GHz sample. The Ports wrapper requests
2.0 GHz by default; no global or per-entry CPU overrides were present when
inspected. The earlier lower reading remains unexplained. Clock samples are
not continuous measurements, and the windows differ in length and animation
phase. The same-binary follow-up below retains this limit rather than claiming
the whole observed difference as a measured cache speedup.

The Down press lasted 160.694 ms and produced exactly one fresh move, `0 -> 1`,
with zero repeat rows in the complete log. The captured frame highlighted
Encyclopedia. Raw-event-to-Gilrs-read delays were 70.881 ms for the press and
38.090 ms for release; these are read timestamps, not completed dispatch or
physical display latency. This single tap does not establish reliability across
all durations, timing alignments, holds or menus.

The owned 120-second deadline returned 130 in game and parent. It restored the
ordinary runtime, movie, launcher and manifest; all 461 manifest entries passed,
owned display resources were released and NX returned. Timings remain
instrumented wall times, not GPU completion or presented FPS. Broader button
checks, physical input feel and ordinary-runtime selection remain outstanding.

### Same-binary cache-off follow-up

Run `run-20261025-160456-11126` used the same `b381ea22...` runtime and private
movie. Its sole game-launcher change was replacing the cache export with
`unset RUFFLE_DDD_STAGE3D_PIPELINE_CACHE`. In matched complete report intervals,
68 sewer frames averaged 23.044 ms in advanceTime and 686.706 ms in render;
16 Pause frames averaged 5.125 ms and 535.500 ms. The reviewer inspected both
states. Only the Escape press/release reached the log. The later Down helper
did not report success as the deadline arrived, and no raw Down or ButtonMenu
row was recorded; this run establishes no Down-tap result.

A separate read-only sampler recorded CPU policy and temperatures every five
seconds. Twenty samples during the logged game included six at 1.608 GHz, nine
at 1.8 GHz and five at 2.0 GHz. The minimum and maximum bounds changed with the
reported current frequency despite the performance governor. No settings were
changed by this test. These observations do not establish the cause of the
policy changes or continuously fixed operation between samples.

The slower render path returned with caching disabled, but these runs do not
support a precise speedup ratio. Further benchmark repetition is not required
for the next practical step: broader button checks using the cache candidate
and the separately prepared Up-wrap correction. The control run again ended
130, restored the exact ordinary four-file set, passed all 461 manifest entries,
released its owned display resources and returned to NX.

### Button-navigation trial

Run `run-20261025-162607-6622` retained the cache-on `b381ea22...` runtime and
launcher. Its private movie, SHA-256
`38e639c326becbaf5168f185afd6857a9f43e56b3ab7c6235c2eb7252dc0f619`, adds the
reviewed eight-byte Up-wrap correction to method 4538 of the existing traced
movie. Whole-file reversal, unchanged frame/menu traces, branch/stack checks and
independent review passed before launch. The owned deadline was 240 seconds.

| Menu | Input | Actual hold | Observed selection |
| --- | --- | ---: | --- |
| Pause | Up | 169.560 ms | `0 -> 2` |
| Pause | Down | 61.748 ms | `2 -> 0` |
| Pause | Down | 159.792 ms | `0 -> 1` |
| Pause | Up | 63.676 ms | `1 -> 0` |
| Pause | Down held | 1,010.740 ms | `0 -> 1 -> 2 -> 0 -> 1` |
| Main | Up | 160.594 ms | `0 -> 3` |
| Main | Up | 59.589 ms | `3 -> 2` |

Each of the six short direction taps produced one fresh selection change and
zero repeats. The hold produced one fresh move and three repeats, all before
release; no later menu row occurred until the next direction press. All 26 raw
edges paired, with no parser warnings. The reviewer inspected every resulting
selection in the captured game frames, including both wrap directions.

Return opened Encyclopedia, Right changed Careers to Monsters, and Return
opened Options from the main menu. Escape left both screens without changing
an Options setting. Encyclopedia returned to the main menu rather than the
preceding Pause menu; that routing is a separate unresolved finding. Reading
the Right release in Encyclopedia took 458.355 ms after its raw event, so these
menu results do not certify uniformly low latency or physical input feel.

The game and parent ended 130. The exact ordinary four-file set was restored,
all 461 manifest entries passed, the owned display resources were absent and
the reviewer inspected NX afterward. The ordinary installation still uses the
earlier runtime and movie. This trial supports the next uninstrumented candidate
check, not complete menu coverage, later-game save validation or PortMaster
catalog readiness. The final private log is SHA-256
`e31a19b04ebcb212fc62baeaa2900a8cb984e5cebd2ccfb6f56b2bdb8e350b93`.

## Measurements after physical play — October 26

The first human playtest completed the Sewer and reported working controls with
noticeable lag. During 74 complete report intervals covering 78.782 seconds of
combat, the runtime recorded 611 update loops. The mean game tick was 114.303 ms;
movie composition averaged 5.654 ms, frontend rendering 8.066 ms and input polling
0.287 ms. The input drain never reached its limit. This locates most remaining
cost inside the tick, which includes Starling's Stage3D rendering, but does not
identify a specific expensive command.

[`stage3d-timing.patch`](stage3d-timing.patch) adds optional command and draw-phase
measurements on top of the pipeline-cache source above. Its SHA-256 is
`be62afa9b47ed37839083d40e19d9520694c34359ed78e826744efeff8f088cc`.
The local source checkpoint is `724690d5fca7678e0497a80c6d860a8d5932a693`,
whose parent is the cache checkpoint `eb3a0eba...`. It does not include the
later batching experiment. Apply it after `pipeline-cache.patch`.

Only `RUFFLE_DDD_STAGE3D_TIMING=1` enables the measurements. Include
`ddd_stage3d_timing=info` in `RUST_LOG` to receive reports. Each context reports
at a `present` boundary after at least two monotonic seconds. The arrays contain
counts, total milliseconds and maximum milliseconds in this order:

1. DrawTriangles, index upload, vertex upload, program constants, texture upload,
   back-buffer configuration and other commands.
2. Pipeline preparation, staging preparation, pass encoding, submission and
   staging recall. These five measurements are included in DrawTriangles time.
3. Present.

Reports also include the current back-buffer dimensions and sample count.
They are overlapping wall-time measurements; submission can include driver work
or waiting and is not a GPU timer. Disabled measurements take no clock samples.
The patch preserves the existing commands, submission order and buffer contents.
It is diagnostic code, not a performance improvement.

The report accumulation/reset test and offline ARM64 desktop compile check
passed. The guarded dist build completed with two jobs, fat LTO and one codegen
unit. The stripped binary is 27,818,680 bytes, SHA-256
`118d5c1213cb816c4085735858633cbb2f773d67b6aec81c8c5c46089fa90db1`.
Its 16-object dependency audit found no missing requirements or new libraries.
The 90-second native title-only run `run-20261026-100348-29187` completed with
the diagnostic enabled and the final private movie `7406fc2c...`. After excluding
the first warmup report, 41 complete intervals covered 82.987 seconds and 1,897
Stage3D presents at 1024 x 768 with one sample. Mean command wall time was
22.549 ms per present, including 21.557 ms in DrawTriangles. Submission accounted
for 19.609 ms; pipeline preparation was 0.994 ms, vertex uploads 0.140 ms and
program-constant updates 0.341 ms. These are title-screen measurements, not combat
timings or presented FPS. The captured frame showed the DDD logo correctly.

The deadline ended the game and parent with status 130. The original four-file
installation was restored, all 461 manifest entries passed, both the ordinary
profile and the human play profile retained their exact hashes, and the reviewer
inspected NX Redux after cleanup. The completed runtime log is SHA-256
`678b3249808ed17c0a4a5742e69ea006008735555fa7cfe909aeca43f6f24504`.
The diagnostic identifies submission as the next area to investigate; it does
not itself improve performance. No inputs or listening test were requested.

### Ordered-submission experiment rejected

A separate private experiment retained each upload/draw pair as two command
buffers and submitted groups at present, readback, reconfiguration or 32 draws.
Staging chunks were closed at every draw and recalled only after submission.
It passed the ARM64 compile check and dependency audit, but its native ordering
fixture failed four of fourteen pixel checks. Earlier draws observed later
uniform, vertex or index data; the render-target case also failed. Texture
updates, readback snapshots and reconfiguration passed. The reviewer inspected
the composite and confirmed the mismatches.

Source checkpoint `15b9d57c240bd0511d35ae18a606ff8f9841388a` and runtime
`3c9421119bbfbdf2d642fcd97ba9b113d8dfcf67c756ee3ddf6249d9f6d7b4bd` are
rejected experiments, not install candidates. The DDD timing comparison was
cancelled at this gate. The finite fixture exited with failure status 1,
released its display resources and returned to NX Redux; the ordinary four-file
installation and human save hashes remained unchanged.

This reproduces the earlier same-buffer mutation failure despite separate
command buffers. Source inspection found ordered replay in the pinned wgpu GLES
backend, but does not establish where the failure originates. A future attempt
needs either a minimal native graphics reproducer or separate per-draw buffer
data. Do not repeat submission grouping alone or promote this binary. The
human-tested pipeline-cache runtime remains the fallback.

### Constant-ring follow-up

The [constant-ring experiment](CONSTANT-RING.md) gives each draw its own program
constant regions while keeping vertex/index submission barriers. It passes all
fourteen native fixture checks and renders the DDD title correctly. One
same-binary title comparison recorded 19.440 ms per present with the change
versus 21.445 ms without it. CPU clocks varied, and combat feel remains
unverified. This is a candidate for ordinary play feedback, not a claim that
the reported lag is fixed. The SDL frontend remains a separate future option.
