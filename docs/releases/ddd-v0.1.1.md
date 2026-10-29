I’ve made this port on my original TrimUI Brick and would appreciate help testing it on other devices and firmware. I developed the port with AI assistance.

You need your own purchased Windows Steam copy of Deep Dungeons of Doom and a handheld running 64-bit ARM Linux (aarch64), glibc 2.31 or later, and WestonPack 0.2. The download contains no game assets or saves.

## Changes in v0.1.1

Corrected controller setup on Knulli and improved input diagnostics.

## Testing so far

| Device or firmware | Status |
| --- | --- |
| Original TrimUI Brick with NX Redux | Earlier builds played successfully and passed setup checks. |
| Other firmware on the Brick | Untested, testers wanted |
| muOS | Untested, testers wanted |
| dArkOS | Untested, testers wanted |
| AmberELEC | Untested, testers wanted |
| Knulli | RG34xxSP starts; controls need retesting with this update. |
| ROCKNIX | Untested, testers wanted |

Please test this build on your device; the table records earlier results. The other firmware entries are testing requests, not confirmed compatibility. See the [testing results](https://github.com/Hkattelu/TrimUI-Brick-Ports/blob/main/ports/deep-dungeons-of-doom/portmaster/TESTING-MATRIX.md) for details. Android and 32-bit firmware are not supported.

## Install

1. Back up an existing installation and profile before updating. Download `deepdungeonsofdoom.zip`, place it in your firmware’s `PortMaster/autoinstall/` folder, and open PortMaster to install it. Install WestonPack 0.2 through PortMaster.
2. Find your installed Windows Steam game folder using Steam’s Manage > Browse local files. Copy the **contents** of that folder, including `ddd-0.1-SNAPSHOT.swf` and `META-INF`, into the installed `deepdungeonsofdoom/gamedata/` folder on your handheld. Do not put the game folder itself inside `gamedata/`. You can use a Windows, macOS, or Linux computer to copy the files.
3. Launch the game from Ports. The first launch automatically prepares a handheld-ready `ddd.swf` with button controls and compatibility changes. It leaves the original files unchanged. Later launches reuse the verified `ddd.swf`. If you already have a current prepared `ddd.swf`, you can keep using it without copying the game files again.

If an existing `ddd.swf` is unsupported, the port leaves it untouched. To retry preparation, back it up, then remove only `ddd.swf` and launch again with the game files in `gamedata/`. Do not remove your `profile/` folder.

## Controls and known limitations

D-pad navigates menus, A confirms, B goes back, and L/R defend and attack. Hold Start and press Select to quit.

Trophies and Hi-score are unavailable. Local Missions works.

## Report your test

Reply in the Discord testing thread or [open an issue](https://github.com/Hkattelu/TrimUI-Brick-Ports/issues/new) with v0.1.1, your device, firmware version, and what worked or failed. You can copy this checklist into your report and note anything you didn’t test:

- [ ] First launch finishes setup and opens the game.
- [ ] Controls and combat work and perform well.
- [ ] Menus can be navigated, including skills, stash, Encyclopedia and Options.
- [ ] Music and effects play without static.
- [ ] Progress is saved after quitting and reopening.
- [ ] Exit Game and Start + Select return to the launcher.

Include steps to reproduce problems. `preparation.log`, `log.txt`, and `runtime.log` may help. Check logs for personal paths before sharing, and don’t share game files or saves.

## Developer sources

Download `ddd-portable-sources.zip` for the corresponding runtime sources and reconstruction instructions. This source archive is for developers and should not be placed in autoinstall.
