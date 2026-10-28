# Deep Dungeons of Doom

This unofficial testing build uses native ARM64 Ruffle. Ordinary play on the original TrimUI Brick with NX Redux confirmed working startup and buttons, with improved perceived performance. The latest change disables unavailable Steam menu options and passed muted menu checks on that device. Audio quality, save/reload and Exit were not separately confirmed by the player on this runtime. See `TESTING-MATRIX.md` for the exact scope. Other firmware and devices remain untested, and the offline startup change has not received a DDD-specific PortMaster policy decision.

## Install the testing package

Download `deepdungeonsofdoom.zip`, place it in your firmware's `PortMaster/autoinstall/` folder, then open PortMaster to install it. Use the location documented for your firmware. Do not put the corresponding source ZIP in autoinstall. Back up an existing DDD installation, including its profile, before updating.

The port requires ARM64 Linux, glibc 2.31 or later and WestonPack 0.2. Preparation of your purchased game requires a Windows PC with PowerShell 7.2 or later. Installing the package alone does not supply the game.

## Supply your game

You need your own purchased Windows copy of [Deep Dungeons of Doom](https://store.steampowered.com/app/325090/). The package contains no game files or saves. No Steam client is needed on the handheld.

1. On a Windows PC, unpack `deepdungeonsofdoom/setup/ddd-preparation-tools.zip` into a separate folder. Install PowerShell 7.2 or later if needed.
2. Keep the purchased installation intact, including `META-INF`. From the extracted tools folder, run:

   ```powershell
   ./Prepare-GameCandidate.ps1 `
     -GameFile 'C:/Program Files (x86)/Steam/steamapps/common/deepdungeonsofdoom/ddd-0.1-SNAPSHOT.swf' `
     -OutputDirectory 'C:/private-ddd-prepared'
   ```

   Adjust the game path. The output directory must be new and outside the game and tools directories. Preparation checks the supported original revision and leaves the purchased installation unchanged.
3. Copy only the resulting `ddd.swf` into the port's `deepdungeonsofdoom` folder. Keep the prepared movie and intermediate files private. The expected SHA256 is `a2700be5d4bdc8c7cd2a9443024af2795b4fd40bc13eede4ce3abef25c876d44`.
4. Install WestonPack 0.2 through PortMaster, then launch the port from the Ports menu. WestonPack is supplied separately.

## Controls on the Brick

- D-pad: navigate menus. Left defends and right attacks in combat; L and R provide the same combat actions.
- A: confirm. B: back.
- Hold Start and press Select: quit using gptokeyb.

Consult the in-game prompts for other actions. In the stash, select an occupied slot and confirm to open its action panel. Back closes the panel, and discard uses the game's confirmation screen.

Steam achievements and leaderboards are unavailable. Honor's Trophies and Hi-score buttons are dimmed and skipped during navigation. Local Missions still work.

## Saves and updates

Progress is stored in `deepdungeonsofdoom/profile/`. Keep that folder and `save-backups/` during updates. Quit the game before copying or moving a save.

To carry forward progress, export the latest complete profile after quitting. From the extracted preparation tools, run:

```powershell
./Import-Save.ps1 -ProfileDirectory C:/private/latest-profile `
  -PortDirectory E:/ports/deepdungeonsofdoom
```

Adjust the SD card path. The importer creates a verified backup and refuses to overwrite existing progress. Keep the original installation and export until the copied progress has loaded in-game.

## Runtime and logs

When reporting a problem, include the testing-build version or ZIP checksum, device, firmware/version, resolution, and GPU backend if known. Describe the first failure and how to reproduce it. Check startup, combat, menus, audio, save/reload and both quit methods during ordinary play, and mark anything you did not test. Review logs for personal paths before sharing them. Do not attach purchased game files or saves publicly.

The launcher uses firmware core libraries, SDL and EGL, plus the separately supplied WestonPack. It writes `log.txt` and a bounded `runtime.log` in the game folder; these logs may contain private session information. The modified Ruffle runtime SHA256 is `29735ea9dc077bf8e1253da74bde1cb9c71906cde18334d5e4ef6434bfe7f3ab`.

Thanks to Bossa Studios for Deep Dungeons of Doom and to the Ruffle contributors for the Flash runtime. This unofficial project is not endorsed by Bossa Studios or PortMaster. Port helpers are MIT licensed. See `licenses/` and `SOURCE-AND-LICENSES.md` for component notices and source information. This build is for community testing and has not been accepted into PortMaster.
