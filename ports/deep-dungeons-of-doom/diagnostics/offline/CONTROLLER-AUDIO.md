# Brick controller and audio troubleshooting

These October 24, 2026 findings concern the original TrimUI Brick, its installed
PortMaster Weston runtime, and Ruffle `nightly-2026-10-24`. The ARM64 executable
SHA256 is `6814582ba9bbf9a3cdd062b3e7cf1a37043e75d6c752e665aee4edf7c5dec121`.
Its locked dependencies include Gilrs 0.11.2, gilrs-core 0.6.8, CPAL 0.16.0 and
alsa-rs 0.9.1. The isolated ALSA library is Ubuntu's `1.2.11-1ubuntu0.3`.
No game content, logs or generated binaries are included here.

This page preserves the initial troubleshooting sequence. Subsequent
[gameplay tests](GAMEPLAY-MILESTONE.md) delivered attack and floor-navigation
inputs, and the [owned quit watcher](../brick/DDD-EXIT.md) returned to NX Redux.
The [process-local ALSA recovery experiment](../brick/ALSA-RECOVERY.md) avoided
the observed error flood, but sound was still inaudible to the user. A firmware
test tone was also inaudible; the cause is unknown, and the user deferred audio
work. The [current status](../../README.md) separates these later results from
the historical limitations below.

## Controller discovery confirmed; control behavior unverified

Ruffle initially had no open handle to `/dev/input/event3`, despite Crusty's SDL
log detecting it. Ruffle reads gamepads through Gilrs separately from SDL and
Weston. Exporting this variable in the private child launcher fixed discovery:

```sh
export GILRS_DISABLE_UDEV=1
```

This selects direct `/dev/input` discovery through inotify instead of relying on
udev's joystick labels. It requires no system rule or udev trigger. Retain the
Ports runner's `SDL_GAMECONTROLLERCONFIG`, which carries the chosen button layout.
For a bounded diagnostic, `RUST_LOG=info,gilrs=debug,gilrs_core=debug` records the
discovery path.

In private run `graphics-20261024-233114-7580`, Gilrs reported `TRIMUI Player1` on
`event3`, with UUID `03000000-5e04-0000-8e02-000014010000`. The coordinating agent
also found an owned Ruffle file descriptor pointing to that device. Evidence:
`device-test/ddd-controls-direct-visual-ruffle.log`. This confirms enumeration and
opening the device; it does not establish working controls. That run still showed
static startup logos after guarded input, so menu navigation and gameplay remain
unverified. It used the private keyboard candidate with SHA256
`c92867d7cdf6e86652562889d46641b4ff228feae042ce4b6cb8ca57161d4ce7`.

Ruffle's `-B` mappings translate gamepad buttons into movie keyboard events, for
example `-B start=return` and `-B d-pad-up=up`. Unmapped buttons are ignored.
See [the pinned input translation](https://github.com/ruffle-rs/ruffle/blob/nightly-2026-10-24/core/src/input.rs#L136)
and [the keyboard candidate's actions](KEYBOARD-MENU.md). Do not infer physical
button behavior merely from a mapping or successful device discovery.

## Audio fault and diagnostic isolation

Run `graphics-20261024-232508-3331` repeatedly reported an ALSA
`snd_pcm_poll_descriptors` error with errno `-32`, producing a large log and poor
progress. `--volume 0` mutes output but still creates an audio stream. The earlier
45-second title run had no such stream errors.

CPAL 0.16.0 immediately retries descriptor errors after calling its error callback.
Its underrun recovery covers later availability/write calls but misses this
descriptor-fill failure. In alsa-rs 0.9.1, that failure retains a negative errno,
unlike most calls. A possible source fix must recognize both signs of `EPIPE`,
recover the stream, and stop after unsuccessful or repeatedly ineffective
recovery. No such runtime patch has been built or validated. See
[CPAL's worker](https://github.com/RustAudio/cpal/blob/v0.16.0/src/host/alsa/mod.rs#L643)
and [alsa-rs error conversion](https://github.com/diwic/alsa-rs/blob/v0.9.1/src/error.rs#L54).

A private `pcm.!default { type null }` configuration removed the error flood but
left an active ALSA stream. That plugin polls `/dev/null` and reports available
buffer space without hardware pacing, so it can still consume CPU. It did not
resolve the static-logo result. See [ALSA's null implementation](https://github.com/alsa-project/alsa-lib/blob/v1.2.11/src/pcm/pcm_null.c).

The next diagnostic used a private `ALSA_CONFIG_PATH` containing:

```text
pcm.!default {
    type hw
    card "DDD_NO_AUDIO_DEVICE"
    device 0
}
```

The deliberately nonexistent card makes audio initialization fail. Ruffle then
retains its built-in `NullAudioBackend`, rather than starting an ALSA null stream.
The direct-discovery run above confirmed the expected initialization error and no
audio worker. See [Ruffle's fallback](https://github.com/ruffle-rs/ruffle/blob/nightly-2026-10-24/desktop/src/player.rs#L134).
This isolates input/rendering tests; it does not fix or validate game audio. The
startup stall remained. Do not replace system ALSA files or suppress errors as a
substitute for recovery.

Subsequent bytecode inspection found that `LogosScreen.step` waits for its logo
sound's playback position before returning control to the main game loop. A
stopped sound clock can therefore keep the logos visible without an AVM error.
A bounded timer fallback is being prepared separately; it has not been tested.

## Later input comparison with built-in NullAudio — October 25, 2026

With the later AMF-only dist runtime `7add99d7...`, a private comparison confirmed
the unavailable-card initialization error and reached Pause using the existing
five-byte silent-logo patch. That startup change bypasses the sound-position
gate; the warmed menu trace remained unchanged. A 160.685 ms Down press still
produced one fresh move and four repeats, ending on Exit Dungeon in the captured
frame. Disabling audio initialization did not resolve the selection failure.
See [the input measurements](../runtime/ruffle-input/README.md) for the
raw-to-Gilrs-read timings and their limits.

The owned deadline and cleanup completed, the ordinary candidate was restored,
and NX returned. This was a performance diagnostic, not an audio repair or
listening test. Audio remains deferred at the user's request, and physical input
feel remains unverified. The subsequent same-binary bounded-drain/timing A/B test
also used built-in NullAudio and the same silent-logo movie. Ordinary polling
produced five menu moves and draining produced three, still failing the intended
single selection. Baseline tick wall time dominated the measured loop, averaging
about 710 ms in the sewer and 539 ms in Pause; that scope includes Stage3D work
invoked by game code. It is not a CPU-only or presented-FPS measurement. Both
bounded runs restored the ordinary runtime and returned to NX; draining remains
unselected. Full evidence and measurement limits are in the input notes above.

## Exit and save boundaries

The direct-discovery run ended with timer exit code `143` and
`westonMountReleased=yes`. Its private cleanup record is
`device-test/ddd-controls-direct-visual-cleanup.txt`.

Gamepad Escape is delivered to the movie; it is not a guaranteed process exit.
The inspected upstream [gptokeyb](https://github.com/PortsMaster/gptokeyb/blob/main/src/util.cpp#L393)
and [gptokeyb2](https://github.com/PortsMaster/gptokeyb2/blob/master/src/util.c#L463)
kill paths select processes by name or command pattern and may force-kill them.
They do not verify a PID's saved start time. A plain `ruffle` target is also
unreliable with an explicit dynamic-loader
invocation. Keep the launcher's owned PID/start-token cleanup and deadline until
a quit chord has been integrated and tested against that same cleanup path.

Current diagnostics store saves under each run's private directory. A fresh run
therefore cannot prove persistence. Save/load validation needs two runs using the
same dedicated test profile and stable movie origin, without touching the user's
existing game saves.
