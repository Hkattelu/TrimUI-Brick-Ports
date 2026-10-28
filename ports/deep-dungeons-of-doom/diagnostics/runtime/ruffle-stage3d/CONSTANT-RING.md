# Per-draw program constants — October 26, 2026

This opt-in renderer experiment passes the Brick's 14-pixel ordering fixture
and renders DDD's title correctly. In one same-binary comparison it reduced
mean Stage3D command wall time from 21.445 to 19.440 ms per present. Combat feel,
later-game rendering and full-game acceptance were unverified at that gate.
The human follow-up below confirms smoother play, with remaining issues.
The earlier human-tested `b381ea22...` runtime is retained as a fallback.

## Source and behavior

[`constant-ring.patch`](constant-ring.patch) applies after the documented
[`stage3d-timing.patch`](stage3d-timing.patch), from local source checkpoint
`724690d5fca7678e0497a80c6d860a8d5932a693` to
`97c92f1ea0171b9c93872aea428f3380b900aa0c`. Its SHA-256 is
`03f08e4ab42240b9694b32dec92edfefbbda0adf7c3ae11d981ec027edb02dfd`.
It includes the necessary submission and readback changes; do not apply the
rejected ordered-submission experiment separately. The local commit IDs record
private build history, not commits available from upstream.

The design adapts the per-draw uniform regions in
[Fancy Pants patch 0011 by crxssrazr93](https://github.com/crxssrazr93/fancypants-portmaster/blob/86a641c2aa6a3901efddcaa492b37e8f3e27ce13/build/ruffle-patches/0011-PortMaster-port-Stage3D-uploads-without-a-submit-con.patch)
to the newer Ruffle renderer. The reference revision is
`86a641c2aa6a3901efddcaa492b37e8f3e27ce13`. Its Ruffle patches use MIT/Apache-2.0
terms; retain its [license notice](FANCYPANTS-LICENSE.md) and the existing
[Ruffle notices](../ruffle-amf/RUFFLE-LICENSE.md). This patch does not include
the reference's render-pass merging, deferred texture-upload system or SDL
frontend. No purchased game files or compiled runtime are included.

Only `RUFFLE_DDD_CONSTANT_RING=1` enables the change. Program constants remain
in CPU shadow arrays until a draw snapshots them into distinct aligned regions
of a 1 MiB uniform buffer. Dynamic offsets select those regions. Vertex and
index updates still flush prior draws, preserving the same-buffer cases that
failed in the previous experiment. Groups are bounded to 32 draws and also
flush at present, readback, reconfiguration and ring wrap. Readbacks retain a
snapshot of the back buffer. The ring cursor resets after the present flush.
With the flag unset, draws keep the existing immediate submission path.

Keep `RUFFLE_DDD_STAGE3D_PIPELINE_CACHE=1` for the separately tested pipeline
cache. The AMF reference fix, bounded input drain, DDD save origin and button
mappings are unchanged. Timing remains separately opt-in; ordinary play need
not enable `RUFFLE_DDD_STAGE3D_TIMING`.

## Focused checks

The offline ARM64 desktop check and guarded dist build passed with two jobs,
fat LTO and one codegen unit. The stripped runtime is 27,826,488 bytes, SHA-256
`3d8a8e5c9c461cf556ffe5fdece7d86868b4032edac16128a740d0975476c802`.
The 16-object ELF audit found no new libraries or missing requirements.
The exported patch passed a reverse-application check against that exact clean
source. These checks do not establish gameplay compatibility by themselves.

Native fixture `batch-on-XXdrtllE` passed all fourteen checks covering earlier
readback snapshots, changing constants, same-buffer vertex/index updates,
textures, render targets and reconfiguration. Its rendered composite was
inspected. The finite fixture returned parent status 0, released its display
resources and returned to NX Redux. Its complete log has SHA-256
`b1fcd1353fde6e89e8c8b251ab588bc6cdceb9be9548e90108abe18cae18a615`.

Two 90-second title-only runs used the same new runtime, final private movie
`7406fc2c...`, separate copies of the human profile, 1024 x 768 and one sample.
No controller inputs were injected. Both title captures were inspected.
Each Stage3D summary excludes its first warmup report; runtime summaries select
only complete intervals between the first and last Stage3D report boundaries.

| Measurement | Ring enabled | Ring disabled |
| --- | ---: | ---: |
| Run | `run-20261026-105634-14860` | `run-20261026-110512-30956` |
| Stage3D presents in selected reports | 2,035 | 1,954 |
| Mean total command time per present | 19.440 ms | 21.445 ms |
| Mean game tick in selected runtime intervals | 26.299 ms | 28.105 ms |
| Mean frontend rendering | 8.118 ms | 7.996 ms |
| Observed in-run CPU frequency sample | 1.8 GHz | 2.0 GHz |

The total command sum includes DrawTriangles, index/vertex uploads, constants,
textures, configuration, other commands and present exactly once. Draw's five
subphases are already included and must not be added again. With the ring,
submission time moves into vertex-upload flushes and present; comparing only
the draw or submit subphase would greatly exaggerate the improvement.

These are overlapping CPU-side wall times from title screens. The clock samples
do not establish a fixed frequency throughout either run. Do not infer a precise
gameplay speedup, GPU completion, presented FPS or input feel from this pair.
The next useful validation is ordinary physical play, without a timed combat
script. Preserve the completed Sewer profile and retain the prior runtime.

Both deadlines returned 130 and restored the exact ordinary four-file set.
All 461 immutable manifest entries passed after each restore; ordinary and human
profile hashes remained unchanged. Owned display resources were released, and
NX Redux was inspected afterward. Complete runtime log SHA-256 values are:

- Enabled: `32c186e9c3d3f5a5252d4add5a4f6ce7f27aa492adb9c033171fb451c35f0009`.
- Disabled: `be4afb04554d71012ff785133393c0bd2206ee55bcf458e4822facddcd7f9a69`.

## Human follow-up and memory cleanup

In `run-20261026-112045-19084`, Himan reported that this version was definitely
smoother and that controls felt fairly responsive. He reached the next dungeon's
final boss, but menu openings and floor changes still dropped frames. He found
the game only somewhat playable and emphasized the missing audio. This is
acceptance of the improvement, not of the overall experience or every menu.

The apparent freeze while returning from the loss screen was a kernel
out-of-memory kill of the exact recorded runtime PID 19992. Both child and
parent returned 137. The ordinary four-file installation was restored, all 461
manifest entries passed and NX Redux returned. The updated save was copied to a
new private host backup; its parsed gameplay fields include `inDungeon=false`,
day 3 and 35 gold. This parsing does not prove the next reload.

Investigation found ten obsolete DDD diagnostic staging folders occupying
470,304 KiB in `/tmp`, which is tmpfs on this device. They were preparation
artifacts left behind by this project, not required by the running game. Each
flat directory was copied to a new private SD-card archive, compared by SHA-256,
synced and rechecked before its RAM copy was removed. No save, firmware file or
other application's temporary directory was removed. `MemAvailable` rose from
278,452 to 748,468 KiB, while `Shmem` fell from 477,124 to 6,824 KiB.

Future diagnostic payloads must be staged on the SD card. Keep only small owned
process/socket files in `/tmp`; retain source and recovery evidence off RAM.
The earlier title comparisons did not control this accumulated memory pressure,
so they cannot establish a precise speedup. Menu/floor behavior and the dungeon
exit need another ordinary human session after cleanup. Do not change cache
eviction or the renderer solely on the unconfirmed assumption that they caused
these stalls.

The complete human runtime log has SHA-256
`5ecde09a6d7087342a5f131987865e3c93cda07875c5be72b566535a4be3a2bb`.
The user confirms that other games have speaker audio. Revisit DDD's intentional
NullAudio configuration through the normal PortMaster route; no sound fix or
listening acceptance is established yet.

After cleanup, an untimed follow-up was installed using the same renderer and
movie. It replaces the deliberately unavailable ALSA card with the isolated
ALSA configuration that loads PortMaster's normal routing, and restores Ruffle's
standard application volume of 1. System mixer and saved volume settings are
unchanged. The latest human profile was backed up again without reseeding it,
all 461 installation entries passed, and available memory remained about
732 MiB. This candidate is ready through Tools → DDD Play Test; sound, transition
smoothness and dungeon-exit behavior still require the user's normal play.
All of its staging and restore files reside on the SD card.

That follow-up has now received human feedback: music and sound are audible and
improve the experience, but the player still reports lag, intermittent static,
and missing visible focus on the dungeon-entry Back/Go buttons. The run recorded
two ALSA POLLERR errors. They are a diagnostic lead, not a confirmed explanation
of the static. Its failed physical quit attempts were short Select taps while
Start was held, below the old helper's 800 ms threshold. See the
[exit correction](../../brick/DDD-EXIT.md) for recovery and integrated testing of
the press-based replacement. The current audio path remains unchanged while the
static is investigated; this feedback does not establish full quality acceptance.
