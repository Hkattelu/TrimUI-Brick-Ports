# Private offline startup probe

`Prepare-OfflineProbe.ps1` targets the verified purchased DDD SWF revision with
SHA256 `595142a1136f286e1d76913722b46bf7dd207a5a326fe174170feab90325b4e0`.
It uses the existing AIR-library preparer to preload the caller's original
ActionScript dependencies, then changes four instruction bytes on the bootstrap
branch taken when native Steam initialization fails. That branch retains its
false initialization result and null `Steamworks.current`; the exit call is
replaced with stack cleanup. The successful-initialization ownership-check branch
is unchanged. No Steam response or ownership result is fabricated.

```powershell
./Prepare-OfflineProbe.ps1 -GameFile $purchasedSwf -OutputFile $privateOutputSwf
```

Create the private output directory first. It must be outside the installation
and this source package. The script refuses unknown input revisions, existing
outputs and paths through junctions or symbolic links. Both the intermediate
`.air-input.swf` and final SWF contain purchased content; keep them private.
Only this helper source belongs in a distributable package.

The game already selects `DummyAchievementDispatcher` and `DummyScoreDispatcher`
when Steam is unavailable. Its Steam adapters are created only on the nonnull
branch. Static inspection found no other native Steam access outside the mapped
bootstrap and adapters; it cannot exclude reflection. The constructor's missing
Steam diagnostic does not exit, but the alternate analytics/error-reporting paths
remain in place. These paths still need runtime verification.

This is a Ruffle probe: its existing `ExtensionContext` stub lets the original
wrapper report native initialization as unavailable. A runtime that throws while
constructing that wrapper would need additional compatibility work. Steam
achievements, leaderboards, overlays and cloud are not provided here. A displayed
title screen does not establish gameplay, local-save reliability or a finished
PortMaster port.

Preparation checks verified that preloading preserves every original movie-body
byte and that only offsets 28219152 through 28219155 differ from the preloaded
movie. The resulting private probe SHA256 is
`f50cc4a7e2539b661dc0243377dd8e73617248dde9a4026a550b5be4655bc7d5`.
The original installed file retained its hash.

## Desktop startup check

Private run `20261024-230617-562` used official Ruffle nightly-2026-10-24,
OpenGL and AIR mode with an isolated profile and muted audio. It reported
`STEAMWORKS API is NOT available!`, reached new-user/save-loading events and
`[Starling] Initialization complete.`, and did not report a call to the native
application exit stub. The owned 40-second test closed with exit code 0; the
private SWF retained the hash above. These observations establish startup
progression with unavailable Steam, not a successful gameplay test.

The desktop Ruffle window was not visually inspected because its app-access prompt
had timed out during the preceding fixture test. No input was sent. The analytics
trace still mentions Flurry events; its native extension
is unavailable in this runtime, and these logs do not establish delivery.

## Brick startup check and local save origin

The first Brick run failed in `SharedObject.getLocal()` before Starling startup.
The actual movie was under `/mnt/SDCARD/.ports/ddd-runtime-test-20261024/`.
Ruffle's pinned implementation builds its logical save key from the movie URL
and rejects every path component beginning with `.`, including `.ports`; its
error text refers to `..` segments. Changing the physical save directory alone
does not change that logical key. See [the pinned SharedObject implementation](https://github.com/ruffle-rs/ruffle/blob/nightly-2026-10-24/core/src/avm2/globals/flash/net/shared_object.rs#L137).

The private launch was corrected without another game-bytecode change:

```sh
--spoof-url file:///ddd-offline/ddd-offline.swf --base "file://$test_root/"
```

Here `test_root` is the actual private device directory above. The positional
movie argument still loads the real `ddd-offline.swf`, and `--base` keeps relative
resource requests rooted beside that file. The stable movie origin creates save
keys such as `localhost/ddd-offline/ddd-offline.swf/saveSlotData`. The diagnostic
retains `--save-directory "$run/saves"`, so every bounded run has its own test
profile. Passing the former null-reference failure does not demonstrate that a
save can survive exit and load correctly later.

Run `graphics-20261024-231233-27915` on October 24, 2026 then reported Steam
unavailable, local-bank loading and `[Starling] Initialization complete.` The
coordinating agent inspected the temporary `device-test/ddd-title-confirmed.jpg`, captured at
23:12:40 local time: it shows the actual Bossa and Miniboss startup logos, with
visible horizontal color bands. Despite the private capture filename, this is a
startup-logo image, not the DDD title screen. Its SHA256 is
`645aa05417f92be45a78de09811b01911cedb25a572fe9921a1bcd8d85322acd`.
That temporary filename was subsequently reused for the later title capture.
The launch's hash guard accepted the prepared movie hash recorded above.

The 20-second owned timer ended Ruffle with exit code `143`.
`device-test/ddd-title-visual-cleanup.txt` reports `westonMountReleased=yes`;
the coordinating agent verified that NX Redux was running again and USB
keep-awake remained at `0`. No input was sent and audio was muted. The log also
reports missing fallback fonts, which may affect text.

A later run, `graphics-20261024-231430-29380`, used a 45-second child timer within
a 60-second parent deadline. At 23:15:00 local time, about 25 seconds after the
Starling initialization marker, a 1024x768 capture showed the actual Deep Dungeons
of Doom title and click-anywhere prompt. Both the coordinating agent and the
source agent inspected `device-test/ddd-title-later-231500.jpg`; no horizontal
bands were visible in that title frame. Its SHA256 is
`e4c6b8858956cfbf6d48613815055e2a170936f3aa3314459367b9b763f07d1d`.
The later cleanup record reports exit code `143` and `westonMountReleased=yes`.

This confirms visible offline title startup on the Brick. Later inspection of
`LogosScreen.step` found an intentional audio-timed glitch effect that draws
random horizontal colored rectangles. The earlier bands therefore are not, by
themselves, evidence of a rendering defect; exact effect fidelity is unverified.
The prior attribution to deferred clearing was speculative. Input, gameplay,
sound and save/load reliability remain
untested, and correct rendering beyond the inspected title frame is unverified.
Logs and captures stay private and are not part of the source package.
