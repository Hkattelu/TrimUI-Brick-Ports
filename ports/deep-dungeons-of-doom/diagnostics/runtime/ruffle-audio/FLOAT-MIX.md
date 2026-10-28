# Integer output overlap candidate

The Brick selects stereo I16 output. The existing mixer sums voices in that
format through `dasp_sample::Sample::add_amp`, which performs ordinary integer
addition. An optimized reproduction using the actual dasp_sample 0.11 dependency
turns `30000 + 30000` into `-5536`. That wraparound is a concrete distortion risk
when effects overlap. It does not establish the cause of every audible glitch.

`float-output-mix.patch` applies after audio timing checkpoint
`a25e38bc9031ad255ffa4040adeb492489238a89`, producing private source checkpoint
`f03027e8a7f49a21b6c60bd5d0671c8abaa43074`. Set `RUFFLE_DDD_FLOAT_MIX=1`
to enable it. Without the flag, the existing output path remains selected.

For I16/U16 output, the frontend uses the existing floating-point mixer and
converts to I16 with saturation after all active voices have been combined.
Unsigned output retains its existing equilibrium conversion. The device format,
sample rate, buffer policy, audio route and volume settings are unchanged.
Scratch space is allocated before playback, holds 2048 whole output frames,
and is reused in the callback. Timing phases are summed across those chunks.
F32 device output remains unchanged.

Clipping can still distort a signal that exceeds full scale; this change prevents
wraparound, not all distortion. The core's per-voice stereo cross-transform still
uses integer samples. Decoder, resampling, underrun and driver issues are separate.
This patch does not claim to improve attack frame time.

Two focused tests pass in debug and optimized builds: overlap/cancellation across
chunk boundaries, and exact roundtrip of every I16 value plus unsigned equilibrium.
The ARM64 desktop compile check and patch reverse-application check pass. The
optimized build and 16-object ELF dependency audit also pass, with no additional
libraries. Runtime SHA-256:
`3cd3864feb7f664bb28364dffae1ff90364f4e576d4f8b2329fd107e893bf7a9`.
Patch SHA-256:
`6b3376cf51c3e81e980cb7fafebc5bf01e93b17ef9d3cef6b8cfac118ec9a743`.
Two native ordinary-launcher runs used a disposable copy of the latest human
save at application volume zero. The log confirms floating-point accumulation
with the same stereo I16/44100 Hz device configuration. The first run rendered
the title; the second reopened the persistent candidate, accepted ordinary
confirm-button input and loaded the copied progress into the world map.

The first run recorded 751 callbacks after warmup, averaging 1.014 ms of callback
work with a 21.438 ms maximum. It still logged five underruns and one POLLERR.
The earlier probe used a different scene, so these are not an audio-cost A/B
comparison. These silent runs did not establish audible quality; the subsequent
human assessment below supplies that evidence. Attack-specific frame timings
have not been remeasured.

## Quit behavior

The previous private playtest wrapper restored and verified fallback files after
each quit. In the latest session, the runtime and display parent stopped about
one second apart, followed by roughly 12 seconds of SD restoration. The next
ordinary play entry delegates directly to the parent launcher and retains the
candidate across exits. Exact-hash fallback restoration remains a deliberate
maintenance operation. Saves are not rolled back with runtime files.

With that entry, two short Start+Select checks reached completed parent cleanup
in 1.14 and 1.35 seconds from the first button press. Both released the Weston
mount and returned to the inspected NX Tools menu. The second launch reused the
installed candidate successfully. These timings cover automated chord delivery
and cleanup; the subsequent human assessment confirms the physical quit behavior.

## Human acceptance — October 26, 2026

Himan played the installed persistent candidate and reported: "Its fixed and
feels great! Both the static are gone and the start+select fix works!!!"
This supersedes the pending audio and physical-quit assessment. Preserve runtime
`3cd3864f...`, source `f03027e8...`, the merged renderer and the persistent entry
as the accepted baseline for those fixes.

The feedback confirms that the reported static disappeared and the physical
quit chord works. It does not establish that all driver warnings disappeared,
or supply new attack-specific frame measurements. No new hardware changes or
save copies were made while recording acceptance; the latest live save must be
retrieved after play before a future device update. PortMaster packaging remains
separate work, with no game files distributed.
