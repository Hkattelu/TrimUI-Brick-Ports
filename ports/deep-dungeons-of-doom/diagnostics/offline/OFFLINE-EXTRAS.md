# Offline Extras menu

The world map's Honor popup labels its Steam service buttons Trophies and
Hi-score. They invoke achievement and leaderboard services that are unavailable
in this port. The October 28 candidate disables both buttons before initial
focus is selected. The existing button class dims them and ignores pointer
activation. The D-pad skips them in both directions.

Missions uses local game progress and remains available under its original unlock
condition. Back remains enabled, including when Missions is still locked. The
dungeon pause menu's Missions and Encyclopedia entries are unchanged.

`Prepare-OfflineExtras.ps1` accepts only the previous StashActions movie
`df2b4af61a382e112eab5fd7e02db17f562325068621b6bb598fa0e9e9029804`.
It replaces a neutralized platform comparison in ExtrasScreen's constructor
with two `enabled = false` assignments. Both movies are 28,621,088 bytes. The
output is `a2700be5d4bdc8c7cd2a9443024af2795b4fd40bc13eede4ce3abef25c876d44`.
The helper checks the input, instruction bytes, output and whole-file reversal.
Purchased game content stays private.

## Validation on October 28

Independent parsing checked the constructor's control flow, stack and scope.
Only its 14-byte instruction span differs. All other methods, constants, assets,
save routines and local achievement/mission tracking are unchanged.

A normal NX Tools launch on the original Brick used portable runtime
`29735ea9...`, zero volume and a copy of the current profile. Rendered checks
confirmed the dimmed buttons, initial Missions focus, left/right wraparound
skipping both services, opening Missions, and returning to the map through Back.
A separate cleanup review reopened the popup and inspected its settled layout.
The real profile remained byte-identical and normal play settings were restored.
These are agent checks, not new human play or listening approval.
