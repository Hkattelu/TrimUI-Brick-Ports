# Selective buffer submission barriers — October 26, 2026

This is a tested renderer experiment, not the selected human-play build. It
preserves buffer ordering on the Brick, but the title comparison shows only a
small reduction in total loop time. It does not resolve the reported lag.

## Source and scope

[`selective-buffer-barriers.patch`](selective-buffer-barriers.patch) applies after
[`constant-ring.patch`](constant-ring.patch), from local source checkpoint
`97c92f1ea0171b9c93872aea428f3380b900aa0c` to
`76cb7013a084cfd04c722e1f6bad896b2845b039`. The patch SHA-256 is
`5d70b325fc233e4c69e48b600e48dcab396ac194ca88b5726ee645c6138d3cbd`.
These commit IDs identify private build checkpoints, not upstream revisions.

Enable `RUFFLE_DDD_SELECTIVE_BUFFER_BARRIERS=1` together with the existing
constant-ring and pipeline-cache flags. With the new flag absent, behavior is
unchanged. The renderer records the vertex/index wrapper addresses referenced by
pending draw commands. An upload to one of those buffers still submits earlier
draws first. An unrelated buffer upload can remain in the ordered command stream.
The dependency set clears after submission and is bounded by the existing
32-draw limit. Address reuse can cause an extra conservative flush, not omit a
required one. No game, audio, save, control or launcher behavior changes.

## Validation

The offline ARM64 desktop check and guarded two-job dist build passed. The
stripped runtime is 27,828,152 bytes with SHA-256
`76a466e4397349f147a88e943627bd438ccb712da492f4781d6a04682a3a7e89`.
The 16-object ELF dependency audit found no additional or missing libraries.
The exported patch passed a reverse-application check against the clean source.

Native fixture `batch-on-XXKPi1sG` passed all 14 pixel checks, including readback
snapshots, changing constants, same-buffer vertex/index updates, textures,
targets and reconfiguration. Its rendered composite was inspected. The fixture
parent returned 0, released Weston and returned to NX Redux.

Two 40-second no-input title runs then used the same binary, separate fresh
profiles, the final private movie and 1024×768 rendering. The first complete
timing report was excluded as warmup. Both captured title images were identical
and were inspected; SHA-256:
`0e8c1200354fdced6ce046ea5c81bd48433a284a029ebd7ad7b75f11a3cd1927`.

| Recorded mean | Flag off | Flag on |
| --- | ---: | ---: |
| Stage3D command wall time per present | 20.895 ms | 18.822 ms |
| Vertex-upload phase per present | 12.451 ms | 0.134 ms |
| Present phase per present | 3.552 ms | 14.076 ms |
| Game tick per loop | 27.756 ms | 25.802 ms |
| Main loop, excluding frontend GUI phase | 34.162 ms | 33.565 ms |
| Stage3D presents sampled | 753 | 812 |
| CPU clock samples at start/end | 2.0 / 1.8 GHz | 1.8 / 1.608 GHz |

Most of the apparent upload improvement moved to presentation. The remaining
gain is modest, and changing CPU clocks prevent a precise speedup claim. These
are overlapping wall-time measurements, not displayed FPS, combat performance
or input feel. No input was injected during either title run.

The title children returned 0 and recorded their timing-success markers. Both
parents returned 8 because the reused fixture wrapper still expected the old
pixel-fixture success text. This was a harness marker mismatch after successful
child completion, not a clean parent pass. Both recorded
`westonMountReleased=yes`, exited and returned to NX. The generator now uses the
title marker for future runs; the retained raw logs are not relabeled. Timing
analysis checks the complete child reports and the enabled flag explicitly.

The installed `3d8a8e5c...` human-play runtime, movie, launcher, manifest and
Tools entry remained unchanged. The latest two canonical save hashes also
remained unchanged. All large diagnostic files stayed on the SD card.

## Next decision

Retain this source checkpoint for a later combined renderer trial. Do not ask
the player to judge it as a lag fix on this evidence. A separate render pass is
still encoded for every draw; investigate grouping compatible draws while
preserving attachments, clears, constants, buffer updates and readback order.
Any such change must pass the ordering fixture and actual rendered checks.
Audio static and dungeon-entry selection feedback remain separate open issues.
