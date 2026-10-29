# Deep Dungeons of Doom v0.1.2 community test

Please help test the port on your handheld. See [the testing matrix](https://github.com/Hkattelu/TrimUI-Brick-Ports/blob/main/ports/deep-dungeons-of-doom/portmaster/TESTING-MATRIX.md)
for existing reports and remaining gaps. Mark anything you did not try as untested.

You need your own purchased Windows Steam game files, a 64-bit ARM Linux
(aarch64) handheld with glibc 2.31 or later, and WestonPack 0.2.

## Install or update

1. Back up the existing DDD installation and profile. Put only
   `deepdungeonsofdoom.zip` in the firmware's `PortMaster/autoinstall/` folder and
   open PortMaster. Install WestonPack 0.2 through PortMaster.
2. When updating from v0.1.0 or v0.1.1, keep `gamedata/`, `ddd.swf`, `config/` and
   `profile/`. Install over the existing port; no game-file conversion or save
   migration is needed for this update.
3. For a first installation, copy the contents of your installed Windows Steam
   game folder, including `ddd-0.1-SNAPSHOT.swf` and `META-INF`, into
   `deepdungeonsofdoom/gamedata/`. Do not nest the game folder inside `gamedata/`.
   A Windows, macOS or Linux computer can copy the files. Launch from Ports;
   preparation happens automatically on the handheld.

An unsupported existing `ddd.swf` is left intact. To retry preparation, back it
up and remove only that file, then launch with the purchased files in
`gamedata/`. Never remove `profile/` to retry.

## What to test

- [ ] First launch finishes setup and opens the game.
- [ ] Controls and combat work and perform well.
- [ ] Menus can be navigated, including skills, stash, Encyclopedia and Options.
- [ ] Music and effects play without static.
- [ ] Progress is saved after quitting and reopening.
- [ ] Exit Game and Start + Select return to the launcher.

There is no timed test or required campaign completion.

## Report the result

Reply in the existing testing thread or [open an issue](https://github.com/Hkattelu/TrimUI-Brick-Ports/issues/new)
with v0.1.2, the device, firmware/version, PortMaster version and what worked or
failed. Include reproduction steps and the ZIP checksum if possible.

For gameplay, input or audio failures, attach **both `log.txt` and `runtime.log`** from
`deepdungeonsofdoom/` after the same launch. The second file contains Ruffle's
runtime diagnostics. Include `preparation.log` if setup fails. Review logs
for personal paths before sharing. Do not post purchased game files or saves.

The source archive is for developers and must not go in `autoinstall/`.
Community testing and this public prerelease do not establish PortMaster
catalogue acceptance. Maintainer policy guidance and documented device results
remain part of the submission process.
