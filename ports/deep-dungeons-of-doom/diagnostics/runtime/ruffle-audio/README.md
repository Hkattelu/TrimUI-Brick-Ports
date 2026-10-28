# Audio callback timing experiment

This is an opt-in diagnostic, not an audio fix or the selected playtest runtime.
It leaves device selection, buffer size, decoding, mixing, volume and error
recovery unchanged. The current player candidate remains the tested merged-pass
runtime while this probe is prepared separately.

The October 26 ordinary-launcher smoke recorded ten ALSA underruns and one
POLLERR with the real audio backend active at application volume zero. Himan
had already reported intermittent static during audible play. Those observations
justify measuring the callback; they do not prove the cause of every burst.

## Source

`audio-callback-timing.patch` applies after the merged-pass source checkpoint
`bad682ccee3dfa5d5ca50fd2e287ea45a99672a6`, producing local checkpoint
`a25e38bc9031ad255ffa4040adeb492489238a89`. These are private source checkpoints,
not upstream commits. Patch SHA-256:
`d83b978f05e559c5a6e926774f68888fc28d43ce15214e7930441db118149234`.
Ruffle license information is retained in the adjacent `ruffle-amf` directory.

Set `RUFFLE_DDD_AUDIO_TIMING=1` and include `ddd_audio_timing=info` in `RUST_LOG`.
The startup record reports channels, sample rate, sample format and requested
buffer policy. The patch does not force an audio configuration.

The mixer uses the same common mixing function for normal and timed calls.
Timed calls measure the sound-instance lock wait, volume/history-lock wait and
mixing wall time. The frontend measures the surrounding callback work, including
the unsigned-sample conversion when relevant. Without the flag, no timing clock
reads or diagnostic report allocation occur in the audio callback.

The audio callback accumulates fixed-size statistics. About every two seconds,
it tries to publish a complete report to a single shared slot using `try_lock`.
A busy or unread slot retains the aggregate for later publication. It never
waits for the reporter or logs from the callback. The main-thread audio tick
takes reports and logs after releasing the slot lock. The last incomplete
interval can be absent when a stream stops.

## Meaning and limits

- `totals_us` and `maxima_us` contain four phases: callback work, instance-lock
  wait, other-lock wait and mixing. The latter three are inside callback work;
  do not add them again. Callback work excludes report bookkeeping and ALSA's
  subsequent write. Waits and scheduler preemption count as wall time.
- `frames` counts sample frames, not interleaved channel samples.
  `chunk_total_us` is the duration of generated audio at the configured rate.
- `gap_gt_previous_chunk` counts callback-start gaps longer than the preceding
  generated chunk. Buffering, startup and pause/resume can cause such gaps;
  this is not an underrun count.
- CPAL's playback timestamp minus its callback timestamp estimates the queued
  audio delay. A nonzero delay shorter than measured work increments
  `past_queue_delay`. Zero-delay calls are counted separately because startup
  can legitimately fill an empty buffer. The timestamps precede the callback;
  the comparison is an indicator, not a measured hardware deadline miss.
- This probe does not directly measure game-thread mixer-lock waits, individual
  decoder costs, clipping, CPU utilization, audible static or input feel.

Run `python3 summarize-audio-timing.py LOG` on one session. The summary requires
one configuration and at least two complete reports after dropping the first
report as warmup. It rejects missing fields, malformed arrays and inconsistent
phase/counter totals. Reports spanning a deliberate pause should be separated
before drawing steady-state conclusions.

## Checks and current status

The ARM64 desktop cargo check passed. Two deterministic Rust tests cover phase
and deadline accounting and preservation of measurements while the report slot
is busy or unread. Three Python tests cover warmup exclusion, corruption and
multi-session rejection, plus ANSI-colored log input. The exported patch passed
reverse application against its clean source checkpoint.

The optimized ARM64 build and 16-object dependency audit passed. Stripped runtime
SHA-256: `cd2f88ee603202f7dcf1b424b24f4cb823630c816ead83eebe2fa7ebf46eea7f`.
A 40-second native run used an isolated archived dungeon save, application volume
zero and the real audio route. Cleanup returned to the inspected NX Tools menu;
the latest human save was unchanged. No system volume or ALSA settings changed.

After dropping the first report, 800 callbacks across 17 reports averaged
0.973 ms of callback work (maximum 16.422 ms). Mixing averaged 0.954 ms;
instance-lock waiting averaged 0.0024 ms and peaked at 0.173 ms. The selected
format was stereo I16 at 44100 Hz. All queued-delay observations were zero,
so these timestamps provide no useful hardware-deadline estimate on this route.
Five underrun messages and two POLLERR messages remain in the raw session log.
The 427 callback gaps longer than the previous chunk are not underrun counts.

This idle dungeon sample does not establish the cost of attacks or bonus effects.
It gives no evidence of sustained expensive mixing or callback lock contention
in that scene. Integer output overlap and the 48000 Hz ALSA slave route remain
separate investigation leads. Listening and normal-play feedback are necessary
before claiming an audio-quality fix.
