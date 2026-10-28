# Deep Dungeons of Doom v0.1.0 Test Build

This unofficial port has been played on the original TrimUI Brick with NX Redux. Other devices and firmware remain untested. The latest change disables unavailable Steam menu options and has only been agent-checked. The port was developed with AI assistance.

You need your own purchased Windows Steam game files, a 64-bit ARM Linux (aarch64) handheld with glibc 2.31 or later, and WestonPack 0.2. The package includes no game files or saves.

## Install

1. Back up any existing installation and profile. Put `deepdungeonsofdoom.zip` in your firmware’s `PortMaster/autoinstall/` folder and open PortMaster. Install WestonPack 0.2 through PortMaster.
2. On a Windows, macOS, or Linux computer, copy the contents of your installed Windows Steam game folder, including `ddd-0.1-SNAPSHOT.swf` and `META-INF`, into the installed `deepdungeonsofdoom/gamedata/` folder on the handheld. Do not nest the game folder inside `gamedata/`.
3. Launch from Ports. The first launch prepares a handheld-ready `ddd.swf` without changing the original files. Later launches reuse the verified file. If you already have a current prepared `ddd.swf`, you can keep using it without copying the game files again.

An unsupported existing `ddd.swf` is left intact. To retry, back it up and remove only `ddd.swf`, then launch again with the game files in `gamedata/`. Never remove `profile/` to retry.

## Controls and saves

D-pad navigates menus, A confirms, B goes back, and L/R defend and attack. Hold Start and press Select to quit. Trophies and Hi-score are unavailable; local Missions works. Progress is stored in `deepdungeonsofdoom/profile/`. Back it up before updating and quit the game before copying it.

## Report problems

[Open an issue](https://github.com/Hkattelu/TrimUI-Brick-Ports/issues/new) with v0.1.0, your device, firmware version, and steps to reproduce the problem. `preparation.log`, `log.txt`, and `runtime.log` may help. Check logs for personal paths before sharing and do not post game files or saves.

This project is not endorsed by Bossa Studios or PortMaster. Port helpers are MIT licensed; see `licenses/` and `SOURCE-AND-LICENSES.md` for component notices and source information.
