# Brick controls

The private build uses the D-pad and buttons; analog sticks are not required.
Himan accepted combat, the skill tree, Encyclopedia and Options during ordinary
play. The installed stash revision also passed native transactions and save/reload
on a disposable profile. Human feedback on that revision is still open. See
[menu coverage](diagnostics/offline/MENU-COVERAGE.md) and
[stash checks](diagnostics/offline/STASH-ACTIONS.md) for the tested scope.

## Main controls

Honor's Trophies and Hi-score buttons require unavailable Steam services. The
current portable candidate dims them and skips them during navigation. Local
Missions remains available under its original unlock condition.

| Ruffle logical control | Keyboard input | Action |
| --- | --- | --- |
| Left trigger / L shoulder | Left | Defend; previous choice where applicable |
| Right trigger / R shoulder | Right | Attack / pick up loot; next choice where applicable |
| D-pad | Arrow keys | Navigate menus, map links and character choices |
| South | Return | Confirm / enter dungeon |
| East | Escape | Back / Pause |
| West | Space | Use item; return focus to map / close map entry panel |
| North | C | Character information; focus map's stash/extras buttons |
| Start + Select | Separate exit watcher | Quit when the second button is pressed; holding either and tapping the other also works |

These are Ruffle's logical controls, not verified printed face-button labels.
With NX's active Nintendo mapping, raw button 304 produces Escape and raw 305
produces Return. The native tests check this mapping before sending input.
Start and Select are omitted from the game's mapping so quitting does not also
confirm or back out of a game screen. Home is not wired to quit.

## Contextual controls

| Screen | Controls |
| --- | --- |
| World map | Arrows follow map links. C focuses stash/extras; Up/Down changes that selection and Return opens it. Space restores map focus. |
| Skill tree | Arrows select skills and scroll; Return buys or activates; Space cycles unlocked characters; C shows career stats; Escape closes stats or returns to the map. |
| Encyclopedia | Left/Right changes category; Up/Down selects entries; Escape returns to the main menu or Pause, depending on where it was opened. |
| Options | Up/Down cycles choices in display order across both columns; Return activates; Escape returns. Reset confirmation uses Return for Yes and Escape for No. |
| Stash inventory/chest | Arrows select an item; Space switches inventory/chest. Return or C opens item information and its action buttons. Escape leaves the stash. |
| Stash item actions | Left/Up selects Move; Right/Down selects Discard. Return activates the selected action. Escape closes the panel. Held Confirm performs one action. |
| Stash confirmation/warning | Return confirms or dismisses; Escape cancels a discard to item information. Navigation does not move the selection behind the modal. |
| Map shop | Left/Right selects; Return opens the purchase panel; Escape leaves. Purchase confirmation uses Return/Escape. |
| Extras | Left/Right selects enabled buttons; Return activates; Escape closes. Online services remain unavailable. |
| Dungeon shop | Left skips an offer and spends finite stock; Return requests purchase; Return/Escape confirms/cancels. Input waits for arrival and is blocked during level-up/fade-out. |

Skipping a dungeon-shop offer is not reversible browsing. Shop and Extras rows
record implemented mappings, not exhaustive native transaction coverage. The
installed stash panel replaces the earlier immediate-transfer and C-then-Space
discard controls. Transfer, swap and discard still use the original game routines.

## Validation limits and history

The four October 26 stash runs returned to NX through Start+Select in 1.23–1.47
seconds. They preserved the canonical save, working audio configuration and
accepted attack runtime. Agent runs used a copied profile and zero runtime volume;
they do not provide new listening approval or physical input-feel evidence.

Earlier input timing, Back routing and hidden discard experiments remain in
[button navigation](diagnostics/runtime/ruffle-stage3d/README.md#button-navigation-trial),
[local Back](diagnostics/offline/LOCAL-BACK.md) and
[discard history](diagnostics/offline/STASH-DISCARD.md). Their earlier pending
checks and controls do not describe the installed stash revision. No claim is
made that every nested screen, late dungeon or other firmware has been tested.
