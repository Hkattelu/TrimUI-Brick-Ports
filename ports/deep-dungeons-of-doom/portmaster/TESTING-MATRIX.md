# DDD testing results

Updated October 28, 2026 for v0.1.0 Test Build.

## Where it has been tested

| Device | Firmware | Result |
| --- | --- | --- |
| Original TrimUI Brick | NX Redux | Played successfully. Combat and buttons received positive player feedback. |
| Original TrimUI Brick | Other firmware | Untested. Testers wanted. |
| Other handhelds | muOS | Untested. Testers wanted. |
| Other handhelds | dArkOS | Untested. Testers wanted. |
| Other handhelds | AmberELEC | Untested. Testers wanted. |
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
