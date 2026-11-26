# Deep Dungeons of Doom v0.1.6 community test

Please launch this build from your handheld's Ports menu. The installed `deepdungeonsofdoom/TESTING-MATRIX.md` records earlier reports and the remaining hardware checks.

You need your own purchased Windows Steam game files, a 64-bit ARM Linux
(aarch64) handheld with glibc 2.31 or later, and WestonPack 0.2.

## Install or update

1. Back up your existing installation and profile. Put the unopened player ZIP in the autoinstall folder on the card that holds your ports. On AmberELEC and ROCKNIX, use `/roms/ports/autoinstall/`. On dArkOS, use `/roms/ports/autoinstall/` on SD1 or `/roms2/ports/autoinstall/` if you selected SD2 for ROMs. The active PortMaster installation's own `autoinstall/` folder also works with the standard launcher. Open PortMaster and install WestonPack 0.2. [PortMaster installation guide](https://portmaster.games/installation/installing-ports/)
2. When updating from an earlier test build, keep `gamedata/`, `ddd.swf`, `config/` and
   `profile/`. Install over the existing port. The next launch reuses your prepared game and profile.
3. For a first installation, copy the contents of your installed Windows Steam
   game folder, including `ddd-0.1-SNAPSHOT.swf` and `META-INF`, into
   `deepdungeonsofdoom/gamedata/`. Do not nest the game folder inside `gamedata/`.
   A Windows, macOS or Linux computer can copy the files. Launch from Ports to prepare the game on the handheld.

An unsupported existing `ddd.swf` is left intact. To retry preparation, back it
up and remove only that file, then launch with the purchased files in
`gamedata/`. Never remove `profile/` to retry.

## What to test

One handheld and its usual settings are enough for a report. We need an AmberELEC 640×480 run and a dArkOS run that says which ROM card you used. An AmberELEC RG351P/M at 480×320 and a dArkOS RGB30 at 720×720 would also cover the small and square screens. On ROCKNIX, report Libmali or Panfrost separately. A Snapdragon/Adreno report is welcome too. If you do not know the driver, give the device model and leave the driver unknown.

- [ ] First launch finishes setup and opens the game.
- [ ] During a fight, tap L to defend and R to attack. Note missed or doubled presses.
- [ ] With a potion equipped and some health missing, open character stats. Find the button that flips More Info (try X on the reported RG40XX H layout). Close stats with Back and tap the same button during play. Report the button label, whether health increased and whether the potion disappeared.
- [ ] In stats, tap Select alone and Start alone. The selected item should stay put. Then check that Left and Right still change the selection.
- [ ] Menus can be navigated, including skills, stash, Encyclopedia and Options.
- [ ] All menu choices and combat indicators fit on screen. Give the resolution and describe any cropped edges.
- [ ] Music and attack effects are audible before and after pausing. Note silence, static or dropouts.
- [ ] Record a change in progress, quit, reopen the game and confirm that change survived.
- [ ] Exit Game returns to Ports. On a separate launch, hold Start and press Select and check that Ports responds afterward.

Mark each item passed, failed or untested.

## Report the result

Reply in the existing testing thread or [open an issue](https://github.com/Hkattelu/TrimUI-Brick-Ports/issues/new)
with v0.1.6, the device model, firmware version, display resolution, GPU driver if known, PortMaster version and what worked or
failed. Include reproduction steps and the ZIP checksum if possible.

For gameplay, input or audio failures, attach **both `log.txt` and `runtime.log`** from
`deepdungeonsofdoom/` after the same launch. The second file contains Ruffle's
runtime diagnostics. Include `preparation.log` if setup fails. Review logs
for personal paths before sharing. Do not post purchased game files or saves.

Leave the developer source archive on your computer.
