# Deep Dungeons of Doom

Unpublished PortMaster preview for the **original TrimUI Brick with NX Redux**.
The game, music, combat controls and quick quit work in the private playtest.
The package entry has passed focused launch, save/reload and Exit checks on
the Brick. The final audio check remains open. Other devices and firmware have
not been tested.

## Supply your game

You need your own purchased Windows copy of
[Deep Dungeons of Doom](https://store.steampowered.com/app/325090/). The package
does not contain the game. No Steam client runs on the handheld.

1. On a Windows PC, unpack `deepdungeonsofdoom/setup/ddd-preparation-tools.zip`
   into a separate folder. Install PowerShell 7.2 or later if needed.
2. Keep the purchased game's original installation intact, including its
   `META-INF` folder. From the extracted tools folder, run:

   ```powershell
   ./Prepare-GameCandidate.ps1 `
     -Candidate StashActions `
     -GameFile 'C:/Program Files (x86)/Steam/steamapps/common/deepdungeonsofdoom/ddd-0.1-SNAPSHOT.swf' `
     -OutputDirectory 'C:/private-ddd-prepared'
   ```

   Adjust the game path to your installation. The output directory must be new
   and outside both the game and tools directories. Preparation checks the
   supported original revision and leaves the purchased installation unchanged.
3. Copy **only the resulting `ddd.swf`** into the port's `deepdungeonsofdoom`
   folder. Keep the prepared game and all intermediate files private.
4. Install WestonPack 0.2 through PortMaster, then launch Deep Dungeons of Doom
   from the normal Ports menu. NX Redux's tested WestonPack also works. This
   preview pins the revisions listed below.

The expected prepared movie SHA256 is
`df2b4af61a382e112eab5fd7e02db17f562325068621b6bb598fa0e9e9029804`.
An unsupported original version is refused; do not rename an original SWF to
`ddd.swf` or modify the integrity manifest to skip preparation.

## Controls

- D-pad: move through menus. Left and right also provide the game's defend and
  attack inputs during combat; the shoulder controls provide those same inputs.
- Bottom face button: confirm. Right face button: back.
- Left face button: the game's Space action. Top face button: the game's C action.
- Hold Start and press Select: quit to NX Redux.

In the stash, select an occupied slot and confirm to open the item's action panel.
Use directions to highlight an action, then confirm. Back closes the panel.
Discard uses the game's confirmation screen. Empty slots do nothing.

## Saves and updates

Progress lives in `deepdungeonsofdoom/profile/`. Keep that folder and
`save-backups/` during updates. Neither is included in this package. Do not copy
or move saves while DDD is running. Quit normally before powering down.

To carry progress from the private playtest, first export its **latest complete
profile after finishing play**. From the extracted preparation tools, run:

```powershell
./Import-Save.ps1 -ProfileDirectory C:/private/latest-profile `
  -PortDirectory E:/ports/deepdungeonsofdoom
```

Adjust the SD card path for your firmware. The importer creates a verified backup
and refuses to overwrite existing progress. Keep the old installation and export
until the new port has loaded the correct progress in-game. An older PC snapshot
does not include play since that snapshot.

NX's Ports integration stores game folders under its `.ports` directory and
provides them to PortMaster through a temporary mount. Use the firmware's normal
PortMaster install location, not the temporary mount path, for manual SD copies.

## Troubleshooting and build details

Missing game files are reported before graphics starts. If a checksum fails,
restore the named file from the same package version. Runtime/library files are
checked at launch; saves are deliberately outside that manifest. Logs are kept
under `logs/` and may contain private game/session details.

The supported NX WestonPack archive SHA256 is
`4c929287617b1276b5cbffcd188eea77aa979a2a84524fd222d03ed3d408c82b`.
It identifies NX's 0.2.8 Preview 1 build. The catalogue's tested 0.2.7.1 build is
`0bccaeebc11296bb1fe4278c9677cb82965c5a04bcd63745fa09d78228bc1a93`.
The package supplies its required EGL compatibility library locally; it does not
replace firmware libraries or include a WestonPack image.
The modified Ruffle executable SHA256 is
`9df2b904c7e5ffbb31c189ba9431d3197a15c131c7844546994c25fbcbbd85d1`.
It uses its own bundled glibc loader and does not replace firmware libraries.
The metadata's glibc 2.33 value describes the tested host firmware, not the bundled
glibc 2.39. No lower host version is claimed to work.

`bash "Deep Dungeons of Doom.sh" --check` checks installation integrity in a
configured PortMaster environment. It does not launch the game or test sound,
graphics or save loading. A missing-game message is expected before preparation.

## Credits and licenses

Deep Dungeons of Doom is a game by Bossa Studios, copyright 2013 Bossa Studios
Ltd. Game artwork, music, text and executable content remain with their owners.
This is an unofficial compatibility project and is not endorsed by Bossa Studios
or PortMaster. Store credits: [Steam](https://store.steampowered.com/app/325090/).

Port adaptation and original launcher/preparation sources: Himanshu Kattelu,
MIT license. Ruffle and its contributors supply the Flash runtime; its changes
and build provenance are identified in `build-provenance.json`. See `licenses/`
for component notices and `SOURCE-AND-LICENSES.md` for source preparation and
remaining release checks. The screenshot is an unedited private native gameplay
capture; its inclusion here does not grant rights to the game's artwork.

This local review draft has not been submitted to PortMaster. Publication awaits
the final audio check and review of the package and accompanying source materials.
