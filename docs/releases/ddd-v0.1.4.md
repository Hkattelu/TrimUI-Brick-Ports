I’ve made this port on my original TrimUI Brick and would appreciate help testing it on other devices and firmware. I developed the port with AI assistance.

You need your own purchased Windows Steam copy of Deep Dungeons of Doom and a handheld running 64-bit ARM Linux (aarch64), glibc 2.31 or later, and WestonPack 0.2. The player ZIP includes the port. You supply the game files.

## Changes in v0.1.4

Fixed a startup failure that could occur when PortMaster supplied its full controller database. This affected AmberELEC and dArkOS launcher checks. The port also keeps the selected button layout when Weston starts the game.

## Testing so far

All v0.1.4 handheld checks are open. The priority is one 640×480 AmberELEC report, one dArkOS report with the ROM card identified, and separate ROCKNIX reports for Libmali and Panfrost. Please use your usual firmware settings.

| Device or firmware | Earlier results and checks needed |
| --- | --- |
| Original TrimUI Brick with NX Redux | Earlier builds were played on the Brick. Please check music and effects on v0.1.4. |
| Other firmware on the Brick | Testers wanted. |
| muOS | An earlier build was reported working. Retest welcome. |
| Knulli | Earlier testing confirmed controls on the RG34XX-SP with Gladiator II. Please check audio as well as input. |
| ROCKNIX | Libmali and Panfrost hardware tests wanted. Adreno reports are also welcome. |
| AmberELEC | Try 640×480, or 480×320 on an RG351P/M. Check the menu edges and combat indicators. |
| dArkOS | Report SD1 or SD2. An RGB30 at 720×720 on SD2 would cover both the square screen and saving on the second card. |

Please include the resolution you tested. We’re looking for 640×480 and higher resolutions such as 1280×720. Reports at 480×320 and 720×720 are welcome too. [Full testing results](https://github.com/Hkattelu/TrimUI-Brick-Ports/blob/ddd-v0.1.4-test/ports/deep-dungeons-of-doom/portmaster/TESTING-MATRIX.md)

## Install

1. Back up an existing installation and profile before updating. Download [deepdungeonsofdoom.zip](https://github.com/Hkattelu/TrimUI-Brick-Ports/releases/download/ddd-v0.1.4-test/deepdungeonsofdoom.zip), put it unopened in the active PortMaster `autoinstall/` folder, then open PortMaster. On AmberELEC and ROCKNIX you can use `/roms/ports/autoinstall/`. On dArkOS use `/roms/ports/autoinstall/` for SD1 or `/roms2/ports/autoinstall/` when SD2 holds the ROMs. Install WestonPack 0.2 through PortMaster.
2. Find your installed Windows Steam game folder using Steam’s Manage > Browse local files. Copy the **contents** of that folder, including `ddd-0.1-SNAPSHOT.swf` and `META-INF`, into the installed `deepdungeonsofdoom/gamedata/` folder on your handheld. Do not put the game folder itself inside `gamedata/`. You can use a Windows, macOS, or Linux computer to copy the files.
3. Launch the game from Ports. The first launch automatically prepares a handheld-ready `ddd.swf` with button controls and compatibility changes. It leaves the original files unchanged. Later launches reuse the verified `ddd.swf`. If you already have a current prepared `ddd.swf`, you can keep using it without copying the game files again.

If an existing `ddd.swf` is unsupported, the port leaves it untouched. To retry preparation, back it up, then remove only `ddd.swf` and launch again with the game files in `gamedata/`. Do not remove your `profile/` folder.

## Controls and known limitations

D-pad navigates menus, A confirms, B goes back, and L/R defend and attack. Hold Start and press Select to quit.

Trophies and Hi-score are unavailable. Local Missions works.

## Report your test

Reply in the Discord testing thread or [open an issue](https://github.com/Hkattelu/TrimUI-Brick-Ports/issues/new) with **v0.1.4**, your device model, firmware version, resolution and GPU driver if known. Mark each item passed, failed or untested.

- [ ] First launch finishes setup and opens the game.
- [ ] L defends and R attacks during combat. Note any missed or doubled presses.
- [ ] Menus can be navigated, including skills, stash, Encyclopedia and Options. Check for cropped text at your native resolution.
- [ ] Music and attack effects are audible before and after pausing. Note any static or dropouts.
- [ ] A specific change in progress survives quitting and reopening.
- [ ] Exit Game returns to Ports. Start + Select also returns to Ports on a separate launch.

Include steps to reproduce problems. For a gameplay or audio failure, include `log.txt` and `runtime.log` from the same launch. Include `preparation.log` if setup fails. Check logs for personal paths before sharing, and don’t share game files or saves.

## Developer sources

The developer archive includes the corresponding runtime sources and reconstruction instructions. [Download the developer sources](https://github.com/Hkattelu/TrimUI-Brick-Ports/releases/download/ddd-v0.1.4-test/ddd-portable-sources.zip).
