# Deep Dungeons of Doom v0.1.1 community test

This update addresses the report that v0.1.0 starts on an RG34xxSP with Knulli
Gladiator II but accepts no input. It corrects the controller-helper setup and
adds input diagnostics. The fix passes synthetic Linux controller tests;
confirmation on the affected handheld is still needed.

Earlier builds have been played successfully on the original TrimUI Brick with
NX Redux. v0.1.1 preserves that input path. See [the testing matrix](https://github.com/Hkattelu/TrimUI-Brick-Ports/blob/main/ports/deep-dungeons-of-doom/portmaster/TESTING-MATRIX.md)
for confirmed results and remaining gaps.

You need your own purchased Windows Steam game files, a 64-bit ARM Linux
(aarch64) handheld with glibc 2.31 or later, and WestonPack 0.2.

## Install or update

1. Back up the existing DDD installation and profile. Put only
   `deepdungeonsofdoom.zip` in the firmware's `PortMaster/autoinstall/` folder and
   open PortMaster. Install WestonPack 0.2 through PortMaster.
2. When updating from v0.1.0, keep `gamedata/`, `ddd.swf`, `config/` and
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

## Focused Knulli retest

- Check all four D-pad directions, confirm and back at the title and menus.
  A single tap should move once; releasing a held button should stop it.
- Enter gameplay and check L/R for defend and attack. Note missed presses,
  double actions or controls that stay held after release.
- Check Exit Game and Start+Select separately. Confirm a return to the firmware
  menu and that the game can launch again.
- Confirm progress and settings survive quitting and reopening. Use a spare
  profile for destructive gameplay choices; do not reset a real save.

There is no timed test or required campaign completion. Audio and graphics are
unchanged, but please report any new problem. Mark anything you did not try as
untested.

## Report the result

Reply in the existing testing thread or [open an issue](https://github.com/Hkattelu/TrimUI-Brick-Ports/issues/new)
with v0.1.1, the device, firmware/version, PortMaster version and what worked or
failed. Include reproduction steps and the ZIP checksum if possible.

For input failures, attach **both `log.txt` and `runtime.log`** from
`deepdungeonsofdoom/` after the same launch. The second file contains Ruffle's
controller diagnostics. Include `preparation.log` if setup fails. Review logs
for personal paths before sharing. Do not post purchased game files or saves.

The source archive is for developers and must not go in `autoinstall/`.
Community testing and this public prerelease do not establish PortMaster
catalogue acceptance. Maintainer policy guidance and documented device results
remain part of the submission process.
