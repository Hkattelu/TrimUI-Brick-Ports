## Notes

Thanks to Bossa Studios and MiniBoss for Deep Dungeons of Doom. This is v0.1.6 of the unofficial handheld test build, prepared by Hkattelu with AI assistance.

Install WestonPack 0.2 through PortMaster. Copy the contents of your purchased Windows Steam game folder, including `ddd-0.1-SNAPSHOT.swf` and `META-INF`, into `deepdungeonsofdoom/gamedata/`. Launch from Ports to prepare the game. A current prepared `ddd.swf` can be reused. Progress is stored in `deepdungeonsofdoom/profile/`. Back it up before updating.

## Controls

| Button | Action |
| --- | --- |
| D-pad | Navigate |
| A / B | Confirm / Back |
| L / R | Defend / Attack |
| Face button mapped to Space | Drink the equipped potion during play. On the character stats screen, this button opens More Info. |
| Face button mapped to C | Open or close character stats |
| Start + Select | Quit to the launcher |

On the RG40XX H with the reported muOS layout, try X for Space. If your face-button layout differs, find the button that flips More Info, close stats with Back, then use that same button in the dungeon.

Trophies and Hi-score are unavailable. Local Missions works.

## Compile

The accompanying `ddd-portable-sources.zip` contains the Ruffle patch, build instructions and native helper sources. See `RUNTIME-SOURCE.md` for toolchain versions and the source checkpoint.
