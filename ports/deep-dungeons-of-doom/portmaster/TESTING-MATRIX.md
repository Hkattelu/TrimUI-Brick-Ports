# DDD testing results

## v0.1.6 controller checks

The port's Gilrs 0.11.2 library rejected eight of 804 distinct Linux controller profiles sampled from PortMaster and muOS before translation. It accepted all 804 translated profiles. Five simulated Linux layouts delivered both edges of each D-pad direction, all four face buttons, L/R, Start and Select. The layouts covered two Jacaranda and two Andromeda muOS profiles plus PortMaster's `retrogame_joypad`. Parsing a profile alone does not establish which physical button a handheld sends.

The launcher regression covers AmberELEC, dArkOS, ROCKNIX, muOS, Knulli and TrimUI. On Knulli the SDL helper receives the firmware's original layout. On ROCKNIX each graphics driver uses the same controller translation. Physical results for this build are pending across the matrix. Please check Start and Select separately, the quit chord, and potion use in the dungeon.

## v0.1.5 RG40XX H controller retest

A v0.1.4 tester reached character stats and played on an RG40XX H at 640×480 with the Windows Steam files. Select acted as Left, Start acted as Right, and pressing them together quit. The tester reported Funky Jacaranda. PortMaster logged `2601.0_JACARANDA`, Mali driver `r20p0-01rel0`, and a controller mapping that Gilrs rejected at the volume-down field. Potion use during active play was unconfirmed.

A Linux controller replay reproduced the mapping error and the two unintended combat inputs. The v0.1.5 mapping delivered separate Select and Start events, both shoulders, all four face buttons and all four D-pad directions. A handheld retest is pending for potion use, combat and quitting.

## v0.1.4 community test · November 23, 2026

The v0.1.3 launcher could fail before the first frame when PortMaster supplied its full controller database. The v0.1.4 launcher filters large databases for attached devices and passes the selected mappings through Weston. The game runtime and save format are the same as v0.1.3.

| Firmware | Launcher checks on Linux | Handheld reports needed for v0.1.4 |
| --- | --- | --- |
| AmberELEC | 640×480 and 480×320, with PortMaster in the ports folder | 640×480, plus RG351P/M at 480×320 if available |
| dArkOS | SD1 at 640×480 and SD2 at 720×720, including controller mappings across sudo | Specify SD1 or SD2. An RGB30 on SD2 would cover the square display and second-card save location in one run. |
| ROCKNIX Libmali | Crusty X11 route at 640×480 | First frame, controls and both ways to exit |
| ROCKNIX Panfrost | Desktop route at 720×720 | First frame, fullscreen fit and return to Ports |
| ROCKNIX Adreno (optional) | Same desktop route at 1280×720 | A Snapdragon handheld with the driver and native resolution in the report |

These seven runs used the player launch scripts, upstream firmware detection and WestonPack's session selection with simulated input devices, display responses, mounts and game process. They checked the controller mapping delivered to the process, fullscreen dimensions, audio server address, save path and cleanup. The v0.1.3 ZIP reproduced the startup failure on the four AmberELEC and dArkOS configurations. Hardware rendering, button feel, audible output and in-game save/reload still need a player. Earlier muOS and Knulli reports are listed below. Speaker or headphone retests on Knulli and the original Brick are welcome. [PortMaster control scripts](https://github.com/PortsMaster/PortMaster-GUI/tree/872aadd8ecf1bc08c07968f5a173527a3ec18036/PortMaster) · [ROCKNIX control script](https://github.com/ROCKNIX/distribution/blob/1d806accd02e9bbfeca03cb5497179e77c7c18d8/projects/ROCKNIX/packages/apps/portmaster/sources/control.txt) · [dArkOS SD2 setup](https://github.com/christianhaitian/dArkOS/blob/86bac70b51f6264670b95020aa7d3cf2cede622d/scripts/Switch%20to%20SD2%20for%20Roms.sh)

## v0.1.3 test candidate · November 22, 2026

Physical checks are pending for this build. Earlier reports mark muOS, Knulli and a higher resolution as tested. The available Knulli v0.1.1 log identifies an RG34XX-SP, Gladiator II and 720×480. Controls worked and audio initialization failed on that run. The newer firmware-level report does not specify which audio path or build was tested.

Please cover ROCKNIX Libmali and Panfrost separately, AmberELEC, dArkOS, muOS, Knulli and original TrimUI Brick NX Redux. Include 640×480 and a higher resolution. Adreno, 480×320 and RGB30 720×720 are optional. Record the GPU driver if known and the outcome of each item in the tester guide.

### Local verification

| Check | Result |
| --- | --- |
| Catalogue and tester ZIP | pmcheck 0.2.27 and 0.2.33 returned zero errors and warnings on both. The two shared notes cover the Weston-supplied Crusty dependency and the NX/Knulli launcher exceptions. The newer checker also flags the length of the launcher compared with the Weston template. |
| Upgrade from the published v0.1.2 ZIP | Purchased files, the prepared game, settings and a profile sentinel survived. The runtime searches the new library directory. The full linked-dependency notice inventory matches the earlier ZIP. |
| First launch | The shipped ARM64 preparer ran under QEMU with a disposable copy of the Steam inputs. First preparation, repeat launch, interrupted preparation, rejected inputs, locking and save preservation passed. |
| Graphics and input | The catalogue WestonPack's ROCKNIX selection and dispatch code took the Libmali X11 route and the Panfrost desktop bypass with controlled driver responses. Launcher fixtures passed fullscreen argument and session checks at 640x480 and 1280x720 and exercised both Knulli helper commands. These checks used simulated platform services. |
| Brick PNG loading | Under ARM64 emulation, both WestonPack libpng builds rejected zlib 1.2.8, then decoded the cover using the zlib from the NX Redux 2.4.0 PortMaster distribution. |
| Audio | Host ALSA captured the direct PCM samples exactly. The CPAL/PipeWire test captured signal before and after pause/resume at 44.1 kHz. The underrun helper passed its injected invalid-buffer and recovery tests. Earlier Brick firmware audio logged repeated resets, so headphone or speaker playback on the Brick remains a priority. |

No physical handheld was used for v0.1.3. Combat, menu navigation, audible output, in-game save/reload and return to the frontend all need reports from the candidate ZIP.

## Earlier builds through v0.1.2

## Where it has been tested

| Device | Firmware | Result |
| --- | --- | --- |
| Original TrimUI Brick | NX Redux | Earlier portable builds played successfully. v0.1.2 preserves their native input and default ALSA setup; hardware retest pending. |
| Original TrimUI Brick | Other firmware | Untested. Testers wanted. |
| Other handhelds | muOS | Marked tested in the v0.1.1 release. Device and firmware version are not recorded here. |
| Other handhelds | dArkOS | Untested. Testers wanted. |
| Other handhelds | AmberELEC | Untested. Testers wanted. |
| Anbernic RG34xxSP | Knulli Gladiator II | Tester confirms controls work in v0.1.1, but audio fails to initialize. Audio retest needed with v0.1.2. |
| Other handhelds | Knulli | Untested. Testers wanted. |
| Other handhelds | ROCKNIX | Untested. Testers wanted. |

The untested rows are requests for help, not confirmed compatibility. This build requires 64-bit ARM Linux (aarch64), glibc 2.31 or later, and WestonPack 0.2. Android and 32-bit firmware are not supported.

## What was checked on the Brick

| Area | Result | Still needed |
| --- | --- | --- |
| Combat and controls | The player reported smooth combat and working buttons on the October 27 portable build. | Reports from other devices and firmware. |
| First launch | The October 28 build prepared the game in about four seconds, opened the title and menu, and accepted button input. | Fresh-install reports from testers. |
| Trophies and Hi-score | The unavailable buttons are dimmed and skipped during navigation. Local Missions and Back were checked. | Player feedback on this latest menu change. |
| Quitting | Exit Game and Start + Select passed device checks. | Confirm both in normal play. |
| Audio | Earlier builds received positive player feedback. The latest automated checks were muted. | Listen for music, effects and static on this test build. |
| Saves | Setup and update checks preserved existing saves. | Confirm progress survives quitting and reopening this test build. |
| Display | Title and menu inspected at 1024 × 768. | Other resolutions, especially 640 × 480, 1280 × 720 and 720 × 720. |

The October 28 changes add automatic setup and disable the unavailable online buttons. Combat and the runtime are unchanged from the October 27 portable build. Automated checks do not replace playing and listening.

## October 29 input correction

The launcher passed `-x` to legacy `gptokeyb`, which ignores that option and never
creates the intended virtual pad. Knulli now uses `gptokeyb2 -x`, with the older
helper's `xbox360` syntax as a fallback. Other firmware retains native input.
The game-side Weston filter is enabled for the virtual-pad route to avoid reading
both physical and virtual controllers. Input initialization messages are retained
in the existing bounded `runtime.log`.

Launcher checks passed, including both helper APIs, firmware selection, NX
argument handling, error cleanup and saved progress. Real Linux virtual devices,
the official helpers and Gilrs 0.11.2 reproduced the ignored option and verified
press/release events for all ten game controls plus rapid taps. The shipped
Weston filter was inspected; it was not executed on ARM hardware in this pass.
The follow-up tester report confirms working input in v0.1.1, and the supplied
`runtime.log` shows the virtual Xbox pad connected. The original direct-input
failure remains unexplained.

## October 29 audio correction

v0.1.2 preserves audio-service addresses across Weston startup and locates the
firmware's ALSA plugins. This applies to other firmware with the same audio setup
as well as Knulli. An isolated Linux test reproduced the initialization failure;
the correction passed captured-signal and pause/resume checks. Direct ALSA output,
launcher behavior and configuration overrides were also checked. The game and
native runtime binaries are unchanged. Physical output and listening on the
RG34xxSP still need a tester's confirmation. See the [audio investigation](portable/AUDIO-COMPATIBILITY.md)
for evidence and limits.

## Report a test

[Open an issue](https://github.com/Hkattelu/TrimUI-Brick-Ports/issues/new) with the build version, device, firmware version, what you tried and what happened. Include steps to reproduce a problem. Mark anything you did not try as untested. Do not attach purchased game files or saves.

<details>
<summary>Technical verification details</summary>

- Runtime: `29735ea9…`. Prepared game: `a2700be5…`. The October 27 player report used the preceding `df2b4af6…` game file.
- First preparation took 3.99 seconds. Subsequent verification took 0.26 seconds. The output matched the existing prepared game byte for byte.
- Missing or incorrect inputs, unsupported existing output, concurrent preparation, interrupted temporary files and symlinks were checked. Original files and saves were preserved.
- Device checks used separate profiles and zero volume. Startup, menu input and quick quit passed through NX Redux. Temporary services and mounts were released.
- Earlier checks exercised menu, Adventure, Back and Exit with NX Weston, plus input, quick quit and audio underrun recovery with PortMaster's WestonPack. Audio recovery logs do not establish audible quality.

</details>
