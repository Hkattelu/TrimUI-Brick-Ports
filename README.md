# TrimUI Brick Ports

This repository contains unofficial ports for the TrimUI Brick and compatible devices.

## Deep Dungeons of Doom v0.1.0 Test Build

The test build is awaiting review on the [releases page](https://github.com/Hkattelu/TrimUI-Brick-Ports/releases). Port sources are in [ports/deep-dungeons-of-doom/](ports/deep-dungeons-of-doom/).

I’ve been playing this unofficial Deep Dungeons of Doom port on my original TrimUI Brick running NX Redux, and I’d like help testing it on other devices and firmware. I developed the port with AI assistance.

You need your own purchased Windows Steam copy of Deep Dungeons of Doom. You can use a Windows, macOS, or Linux computer to copy the installed game files to your handheld. The download contains no game assets or saves.

## Device testing

- Tested: original TrimUI Brick running NX Redux.
- Untested: other handhelds, and other firmware on the Brick.
- Testers wanted: devices running muOS, dArkOS, AmberELEC, Knulli or ROCKNIX. These are testing targets, not confirmed compatible combinations.

This build requires 64-bit ARM Linux (aarch64), glibc 2.31 or later, and WestonPack 0.2. It does not support 32-bit firmware or Android. See the [testing matrix](https://github.com/Hkattelu/TrimUI-Brick-Ports/blob/main/ports/deep-dungeons-of-doom/portmaster/TESTING-MATRIX.md) for recorded results.

## Install

1. Back up an existing installation and profile before updating. Download `deepdungeonsofdoom.zip`, place it in your firmware’s `PortMaster/autoinstall/` folder, and open PortMaster to install it. Install WestonPack 0.2 through PortMaster.
2. Find your installed Windows Steam game folder using Steam’s Manage > Browse local files. Copy the **contents** of that folder, including `ddd-0.1-SNAPSHOT.swf` and `META-INF`, into the installed `deepdungeonsofdoom/gamedata/` folder on your handheld. Do not put the game folder itself inside `gamedata/`.
3. Launch the game from Ports. The first launch automatically prepares a handheld-ready `ddd.swf` with button controls and compatibility changes. It leaves the original files unchanged. Later launches reuse the verified `ddd.swf`. If you already have a current prepared `ddd.swf`, you can keep using it without copying the game files again.

If an existing `ddd.swf` is unsupported, the port leaves it untouched. To retry preparation, back it up, then remove only `ddd.swf` and launch again with the game files in `gamedata/`. Do not remove your `profile/` folder.

D-pad navigates menus, A confirms, B goes back, and L/R defend and attack. Hold Start and press Select to quit. Trophies and Hi-score are unavailable, while local Missions works.

Report problems by [opening an issue](https://github.com/Hkattelu/TrimUI-Brick-Ports/issues/new). Include v0.1.0, your device, firmware version, and steps to reproduce the problem. `preparation.log`, `log.txt`, and `runtime.log` may help; check them for personal paths before sharing. Please don’t share game files or saves.

## Developer sources

The release also provides `ddd-portable-sources.zip`, the matching runtime sources and reconstruction instructions for developers. Third-party components have their own licenses. See [source and licenses](ports/deep-dungeons-of-doom/portmaster/portable/SOURCE-AND-LICENSES.md).
