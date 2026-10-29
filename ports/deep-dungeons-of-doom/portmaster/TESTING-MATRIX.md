# DDD testing results

Updated October 29, 2026 for v0.1.2 Test Build.

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
