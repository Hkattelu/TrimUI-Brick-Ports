# Deep Dungeons of Doom v0.1.3 community test

Please launch this build from your handheld's Ports menu. The installed `deepdungeonsofdoom/TESTING-MATRIX.md` records earlier reports and the remaining hardware checks.

You need your own purchased Windows Steam game files, a 64-bit ARM Linux
(aarch64) handheld with glibc 2.31 or later, and WestonPack 0.2.

## Install or update

1. Back up the existing DDD installation and profile. Put only
   `deepdungeonsofdoom.zip` in the firmware's `PortMaster/autoinstall/` folder and
   open PortMaster. Install WestonPack 0.2 through PortMaster.
2. When updating from v0.1.0, v0.1.1 or v0.1.2, keep `gamedata/`, `ddd.swf`, `config/` and
   `profile/`. Install over the existing port. The next launch reuses your prepared game and profile.
3. For a first installation, copy the contents of your installed Windows Steam
   game folder, including `ddd-0.1-SNAPSHOT.swf` and `META-INF`, into
   `deepdungeonsofdoom/gamedata/`. Do not nest the game folder inside `gamedata/`.
   A Windows, macOS or Linux computer can copy the files. Launch from Ports to prepare the game on the handheld.

An unsupported existing `ddd.swf` is left intact. To retry preparation, back it
up and remove only that file, then launch with the purchased files in
`gamedata/`. Never remove `profile/` to retry.

## What to test

- [ ] First launch finishes setup and opens the game.
- [ ] During a fight, tap L to defend and R to attack. Note missed or doubled presses.
- [ ] Menus can be navigated, including skills, stash, Encyclopedia and Options.
- [ ] Music and attack effects are audible before and after pausing. Note silence, static or dropouts.
- [ ] Record a change in progress, quit, reopen the game and confirm that change survived.
- [ ] Exit Game and Start + Select return to the launcher.

Mark each item passed, failed or untested.

## Report the result

Reply in the existing testing thread or [open an issue](https://github.com/Hkattelu/TrimUI-Brick-Ports/issues/new)
with v0.1.3, the device model, firmware version, display resolution, GPU driver if known, PortMaster version and what worked or
failed. Include reproduction steps and the ZIP checksum if possible.

For gameplay, input or audio failures, attach **both `log.txt` and `runtime.log`** from
`deepdungeonsofdoom/` after the same launch. The second file contains Ruffle's
runtime diagnostics. Include `preparation.log` if setup fails. Review logs
for personal paths before sharing. Do not post purchased game files or saves.

On ROCKNIX, identify Libmali, Panfrost or Adreno if known. Leave the developer source archive on your computer.
