# Audio compatibility investigation

October 29, 2026. The RG34xxSP tester reports working controls in v0.1.1, but no
audio on Knulli Gladiator II. The supplied `runtime.log` confirms the virtual
Xbox pad and reports `Unable to create audio device: Failed to get default output
config`. Ruffle then continues without an audio backend. The earlier underrun
message in `log.txt` belongs to setup, before Ruffle starts.

## Cause and fix

WestonPack changes `XDG_RUNTIME_DIR` to `/tmp/weston_runtime`. Knulli's audio
service uses `/var/run`, so a client relying on the replaced directory cannot
find its PipeWire socket. Knulli installs the ALSA PipeWire default configuration.
The bundled ALSA 1.2.11 library also has `/usr/lib/alsa-lib` as its fallback plugin
directory; firmware can install the required modules under `/usr/lib64/alsa-lib`
or an architecture-specific directory instead. Ruffle's error message omits the
underlying ALSA error, so the supplied logs alone cannot distinguish these causes.

The launcher now discovers audio sockets before starting Weston and forwards the
audio environment through the privilege wrapper and Weston's command evaluation.
The game locates firmware ALSA plugins in aarch64, lib64 and standard directories.
Paths are shell-quoted, including explicit configuration overrides. Existing
PipeWire/PulseAudio choices take precedence over detection. Direct ALSA keeps the
previous library and default configuration, with its system/user config hooks.
No system configuration, mixer volume, audio daemon or device choice is changed.
Selected configuration/plugin paths are recorded in `log.txt`.

This addresses a shared launch boundary, so it also applies to other firmware
using these audio services or library layouts. It does not establish compatibility
with every device, output driver, Bluetooth configuration or firmware version.

Primary sources used to trace the behavior:

- [Knulli audio installation](https://github.com/knulli-cfw/knulli-linux/blob/57afa662009641d181f57241bcc480119b131530/package/system/knulli-audio/knulli-audio.mk)
- [Knulli runtime directory](https://github.com/knulli-cfw/knulli-linux/blob/57afa662009641d181f57241bcc480119b131530/package/system/knulli-system/xdg.sh)
- [PipeWire socket environment](https://docs.pipewire.org/page_man_pipewire_1.html)
- [ALSA 1.2.11 plugin lookup](https://github.com/alsa-project/alsa-lib/blob/v1.2.11/src/dlmisc.c)

The Knulli source above is the inspected upstream revision, not a dump of the
tester's installed filesystem. The firmware/plugin diagnosis is supported by
that source and the reproduction below; a device retest is still required.

## Focused validation

An isolated x86_64 Linux session used CPAL 0.16.0 and ALSA 1.2.11 with the same
Ubuntu source patches and plugin-directory build setting as the shipped runtime.
The test service exposed a private PipeWire socket and a silent sink, with no
connection to speakers or the user's audio session.

| Configuration | Result |
| --- | --- |
| Old launcher environment | Default output failed: missing PipeWire plugin. |
| Plugin directory corrected alone | Default output failed: audio service unreachable. |
| Audio socket directory corrected alone | Default output failed: missing PipeWire plugin. |
| Both corrected | Default output opened: stereo float32 at 44.1 kHz. |

Using the actual new shell helper, 225,763 frames were captured at the silent sink
(peak 0.13144, RMS 0.08727), with signal present before and after pause/resume.
A separate direct ALSA file/null sink captured 4,410 stereo frames exactly matching
the submitted samples. These are signal checks, not listening approval or a
test of the RG34xxSP's physical output driver.

Repository checks cover socket discovery, absent services, non-socket files,
custom endpoints, configuration overrides, plugin-directory preference, both
controller helpers, native input, NX quoting, privilege-wrapper environment
clearing, exit status and save preservation. Package checks verify the helper is
included and identical to source. The runtime, game preparation, audio recovery
library and other native binaries are unchanged.

Private reproduction scripts and measurements are under
`ddd-port-work/audio-compat-20261029` in the local workspace. Hardware playback,
headphones/Bluetooth switching and listening quality remain unverified for this
update. The tester's input fix is confirmed by their report; audio is pending.
