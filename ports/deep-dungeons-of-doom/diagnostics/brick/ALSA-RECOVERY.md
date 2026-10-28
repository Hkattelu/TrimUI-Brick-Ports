# Experimental ALSA descriptor recovery

`alsa-poll-recovery.c` is an original, process-local workaround for an observed
Ruffle audio failure on the original TrimUI Brick. A bounded hardware run is
recorded below; audible playback and firmware PCM recovery remain unverified.
It changes neither firmware libraries nor the game.

The affected private run repeatedly reported
`snd_pcm_poll_descriptors: Unknown errno (-32)`. Ruffle nightly 2026-10-24 uses
CPAL 0.16.0 and alsa-rs 0.9.1. CPAL immediately retries a failed descriptor fill,
but its existing underrun recovery occurs later in the worker. alsa-rs's fill
path preserves the negative error number, explaining the unusual message.
The experiment uses Ubuntu's isolated `libasound2t64` 1.2.11-1ubuntu0.3.

Source references: [CPAL ALSA worker](https://github.com/RustAudio/cpal/blob/v0.16.0/src/host/alsa/mod.rs),
[alsa-rs descriptor fill](https://github.com/diwic/alsa-rs/blob/v0.9.1/src/pcm.rs),
[alsa-rs error conversion](https://github.com/diwic/alsa-rs/blob/v0.9.1/src/error.rs),
and [ALSA recovery implementation](https://github.com/alsa-project/alsa-lib/blob/v1.2.11/src/pcm/pcm.c).

## Behavior and limits

The normal compilation branch exports only `snd_pcm_poll_descriptors`, using
ALSA's exact C signature and opaque `snd_pcm_t` handle. `pthread_once` resolves
the next descriptor and recovery functions through `dlsym(RTLD_NEXT, ...)`.
The original handle, descriptor array and array capacity pass through unchanged.

On `-EPIPE`, the wrapper calls the real `snd_pcm_recover(pcm, -EPIPE, 0)` once.
Successful recovery permits exactly one descriptor retry. Failed recovery
returns its error; a failed retry returns the retry's error. No failure becomes
success. Recovery runs synchronously on the existing caller thread and prepares
the existing PCM. An underrun can lose buffered sound and produce a discontinuity.

`-ESTRPIPE` is deliberately left unrecovered. ALSA 1.2.11's recovery function can
repeat suspended-device resume attempts indefinitely, sleeping for a second on
each `-EAGAIN`. Calling it here would defeat the bounded retry policy.

Every remaining negative return waits 25 ms, then 50 ms, then at most 100 ms per
call until a successful descriptor result resets the delay. This prevents the
observed immediate error loop from consuming a core. The counter belongs to the
calling thread, so it is shared by any PCMs used on that same thread. At the cap,
persistent failures can still produce about ten caller error messages per second.
ALSA diagnostics remain enabled, and the first recovery attempt on each thread
emits one short marker. Errors are not hidden by a logging filter.

Missing descriptor resolution returns `-ENOSYS` with the same delay. Missing
recovery resolution preserves the descriptor error. There is no PCM close,
reopen, device selection, mixer change or process restart. The wrapper bounds
its own recovery attempts and retry count; it cannot impose a timeout on an
underlying synchronous ALSA or driver call.

## Build and check without a device

Use an existing Linux C toolchain. Set `src` to this source file and `out` to a
new scratch directory outside the checkout. The two test compilation branches
provide a fake ALSA library and driver; they are excluded from the production
shared object. These tests exercise actual ELF interposition without audio
hardware, game files, a graphical session or an ALSA installation.

```sh
set -eu
ulimit -c 0
: "${src:?Set the absolute source path}"
: "${out:?Set a scratch output directory}"
mkdir -p "$out/missing"
gcc -std=c11 -O2 -Wall -Wextra -Werror -fPIC -shared \
    -Wl,-z,defs,-z,relro,-z,now \
    -o "$out/libddd_alsa_poll_recovery.so" "$src" -ldl -pthread
gcc -std=c11 -O2 -Wall -Wextra -Werror -fPIC -shared \
    -DDDD_ALSA_TEST_FAKE -o "$out/libddd_fake_alsa.so" "$src" -pthread
gcc -std=c11 -O2 -Wall -Wextra -Werror -fPIC -shared \
    -DDDD_ALSA_TEST_FAKE -DDDD_ALSA_TEST_NO_RECOVER \
    -o "$out/missing/libddd_fake_alsa.so" "$src" -pthread
gcc -std=c11 -O2 -Wall -Wextra -Werror -DDDD_ALSA_TEST_DRIVER \
    -o "$out/test-driver" "$src" -L"$out" -lddd_fake_alsa -pthread \
    -Wl,--enable-new-dtags,-rpath,'$ORIGIN'
LD_PRELOAD="$out/libddd_alsa_poll_recovery.so" "$out/test-driver"
LD_LIBRARY_PATH="$out/missing" LD_PRELOAD="$out/libddd_alsa_poll_recovery.so" \
    "$out/test-driver" missing-recover
python3 - "$out/libddd_alsa_poll_recovery.so" <<'PY'
import ctypes, errno, sys, time
shim = ctypes.CDLL(sys.argv[1])
f = shim.snd_pcm_poll_descriptors
f.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_uint]
f.restype = ctypes.c_int
start = time.monotonic()
assert f(None, None, 0) == -errno.ENOSYS
assert time.monotonic() - start >= .020
print('PASS missing descriptor symbol returns ENOSYS with backoff')
PY
```

These checks passed on 2026-10-24 using GCC 11.4. They cover concurrent first-call
resolution, argument forwarding, ordinary passthrough, successful underrun
recovery, failed recovery, a failed single retry, suspended and fatal errors,
backoff timing, and both missing-symbol cases. An independent source review found
no blocker in the ABI, thread-local state or retry handling. Neither result
establishes working sound on the Brick.

For ARM64, use the existing Arm GNU Toolchain 13.2.Rel1 and isolated Ubuntu
sysroot. Set `cc`, `sysroot`, `src` and `out` to their absolute paths. No compiler
or system-library installation is part of this step.

```sh
"$cc" --sysroot="$sysroot" \
    -isystem "$sysroot/usr/include/aarch64-linux-gnu" \
    -B"$sysroot/usr/lib/aarch64-linux-gnu/" \
    -L"$sysroot/usr/lib/aarch64-linux-gnu" \
    -std=c11 -O2 -Wall -Wextra -Werror -fPIC -shared \
    -Wl,-z,defs,-z,relro,-z,now,-soname,libddd_alsa_poll_recovery.so \
    -Wl,-rpath-link,"$sysroot/usr/lib/aarch64-linux-gnu" \
    -o "$out/libddd_alsa_poll_recovery.so" "$src" -ldl -pthread
```

The private ARM build is 70,232 bytes, ELF64 AArch64, with only `libc.so.6` in
`DT_NEEDED` and no RPATH/RUNPATH. It requires GLIBC 2.17 and 2.34 symbols, so use
the existing isolated glibc 2.39 loader. The Brick's firmware glibc 2.33 is
insufficient. Source and build identity:

| Item | SHA-256 |
| --- | --- |
| `alsa-poll-recovery.c` | `a115c77b6c33c88509a2242e694f72b011d67376667dd9cef42b1690438fa2b0` |
| Private ARM64 shared object | `f90be5aa32fbb9ff1dce495a2ffd86070320a778d248c5fb560a86a565e8fb7a` |
| Intended target Ruffle ARM64 binary | `6814582ba9bbf9a3cdd062b3e7cf1a37043e75d6c752e665aee4edf7c5dec121` |

The fake-target checks establish the wrapper's retry behavior. The hardware
observation below adds runtime evidence without establishing audible playback.

## Interpreting the hardware counters

Private run `graphics-20261024-235107-21628` recorded one
`alsa::poll() returned POLLERR` message at `2026-10-25T03:51:10.993671Z`, followed
in the captured log by `ddd-alsa: attempting descriptor underrun recovery`.
The recovery marker has no timestamp, so this is the recorded line order, not a
precise timing measurement. The run did not reproduce the earlier descriptor
error flood. This establishes neither successful recovery nor audible sound.

Read-only inspection found the firmware's default playback route uses
`plug` → `softvol` → `PlaybackDmix` → `dmix` → `hw:audiocodec,0`. For this route,
`/proc/asound/card0/pcm0p/sub0/status` describes the shared hardware slave, not
the application's logical PCM. ALSA's dmix implementation explicitly states
that the slave does not set `appl_ptr`; it mixes into the slave's mmap buffer
and uses the slave timer because multiple clients cannot drive that pointer.
Consequently, `appl_ptr=0`, a growing `hw_ptr`, and negative hardware delay do
not by themselves prove that Ruffle failed to write audio. See
[dmix's status handling](https://github.com/alsa-project/alsa-lib/blob/v1.2.11/src/pcm/pcm_dmix.c#L474)
and [direct-plugin timer setup](https://github.com/alsa-project/alsa-lib/blob/v1.2.11/src/pcm/pcm_direct.c#L1464).

Judge playback through direct listening or suitable audio capture. Further
recovery changes are on hold until that evidence or a concrete failing
reproducer warrants them. No mixer or firmware setting was changed for this
inspection.

Himan reported hearing nothing during this listening test. On October 25,
read-only mixer inspection still showed Headphone gain at 0/7 (-42 dB),
playback enabled, and Game volume at 100%. The runtime had also applied a
0.25 volume multiplier. This makes a quiet output path worth testing, but does
not establish the cause of silence. No gain change or successful listening
comparison has been verified; audio remains unresolved.

A subsequent three-second original PCM tone (two softly faded 440 Hz beeps at
0.063 peak amplitude, 48 kHz stereo S16_LE) completed through firmware `aplay`
with the user's current audio routing and no playback error. Himan heard
nothing during that test either, and asked to deprioritize audio for now.
The test changed no mixer controls. Headphone still read -42 dB while digital
volume changed to 9/63; do not infer the user's volume setting from the
Headphone control alone. This baseline does not isolate the cause to Ruffle.
Further listening tests are deferred while save reliability and playability
take priority.

## Scope the next hardware experiment

After source and artifact review, add the shim before Crusty in `LD_PRELOAD` on
the actual isolated loader/Ruffle command only. Preserve the existing library
path, arguments, owned-process timeout and mount cleanup. The following shows
the placement; the omitted arguments still come from the reviewed private
runner and must not be replaced by this sketch.

```sh
LD_PRELOAD="$test_root/libddd_alsa_poll_recovery.so:$DDD_CRUSTY_PRELOAD" \
    "$loader" [existing loader arguments] "$test_root/ruffle" [existing arguments]
```

Do not export this preload into shell helpers, checksums or the entire Weston
wrapper. Crusty's preload previously wrote to stdout during such helpers and
corrupted checksum command substitution. Use the genuine device audio config;
the ALSA null sink and intentionally unavailable-device config test different
paths and cannot establish real playback through this recovery wrapper.

Keep the experiment bounded and inspect the resulting process, audio and
cleanup evidence. A recovery marker proves only an attempted recovery. Success
requires actual sound, stable progress, no repeated descriptor failures, and a
clean return to the menu. Combined Crusty interposition, firmware behavior,
audio quality and latency remain unvalidated. Persistent errors still require
diagnosis rather than treating throttled logs as a repaired audio backend.
