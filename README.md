# TrimUI Brick Ports

This repository contains unofficial ports for the TrimUI Brick and compatible devices.

## Deep Dungeons of Doom v0.1.0 Test Build

The first testing release is being prepared for review and will appear on the [releases page](https://github.com/Hkattelu/TrimUI-Brick-Ports/releases). Port sources are in [ports/deep-dungeons-of-doom/](ports/deep-dungeons-of-doom/).

I’ve been playing this unofficial Deep Dungeons of Doom port on my original TrimUI Brick running NX Redux, and I’d like help testing it on other devices and firmware. I developed the port with AI assistance.

You’ll need:

- Your own purchased and installed Windows Steam copy of Deep Dungeons of Doom.
- A Windows PC with [PowerShell 7.2 or later](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows).
- An ARM64 Linux handheld with glibc 2.31 or later and WestonPack 0.2.

The download contains no game assets or saves. Back up an existing installation and profile before updating.

## Install

1. Download `deepdungeonsofdoom.zip` from the release. On your Windows PC, right-click the ZIP, open Properties, and check Unblock if it is shown. Unzip it, then extract `deepdungeonsofdoom/setup/ddd-preparation-tools.zip` into a separate folder.
2. Find your installed game folder in Steam using Manage > Browse local files. Keep the installation intact, including `META-INF`.
3. In File Explorer, open the extracted tools folder, type `pwsh` in the address bar, and press Enter. Run the command below, adjusting the game path to match the folder Steam opened. The command creates `DDD-prepared` in your Windows user folder. If that folder already exists, change the output name to `DDD-prepared-2` or another new name.

   ```powershell
   pwsh -NoProfile -ExecutionPolicy RemoteSigned -File ./Prepare-GameCandidate.ps1 `
     -GameFile 'C:/Program Files (x86)/Steam/steamapps/common/deepdungeonsofdoom/ddd-0.1-SNAPSHOT.swf' `
     -OutputDirectory "$env:USERPROFILE/DDD-prepared"
   ```

4. Put the original `deepdungeonsofdoom.zip` in your firmware’s `PortMaster/autoinstall/` folder and open PortMaster to install it. Install WestonPack 0.2 through PortMaster.
5. Copy the resulting `ddd.swf` from the output folder into the installed `deepdungeonsofdoom` folder on your handheld. Launch the game from Ports. Keep the prepared files private.

D-pad navigates menus, A confirms, B goes back, and L/R defend and attack. Hold Start and press Select to quit. Trophies and Hi-score are unavailable, while local Missions works.

Report problems by [opening an issue](https://github.com/Hkattelu/TrimUI-Brick-Ports/issues/new). Include v0.1.0, your device, firmware version, and steps to reproduce the problem. Please don’t share game files or saves.

The release also provides `ddd-portable-sources.zip`, the matching runtime sources and reconstruction instructions for developers. Third-party components have their own licenses. See [source and licenses](ports/deep-dungeons-of-doom/portmaster/portable/SOURCE-AND-LICENSES.md).
