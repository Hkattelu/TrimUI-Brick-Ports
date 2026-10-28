# Stash action menu

October 26, 2026. Himan accepted combat, audio, quick quit, the skill tree,
Encyclopedia and Options, but found the stash confusing. The accepted menu movie
still used a different controller path from mouse input: Return transferred an
item immediately, while C opened an information panel without the native Move
and Discard buttons. Its selection overlay pulsed between 10% and 20% opacity.

A silent Brick run on a copy of the latest save confirmed that equipment could
move into the chest, a chest item could move into inventory, information opened,
and discard could be cancelled. Captures showed the missing action buttons.
The test exited through Start+Select in about 1.35 seconds. This was baseline
evidence, not a test of the new candidate.

## Installed interaction

`Prepare-StashActions.ps1` makes Return and C open the original mouse action
panel for the selected item. It reuses the game's existing labels, artwork and
callbacks. Left/Up selects Move; Right/Down selects Discard; Return activates the
visible choice. Discard still opens the original confirmation. Space switches
inventory/chest when no panel is open, and Escape closes the current panel.

The item and action indicators use a steady 25% white overlay. The action panel
initially selects Move and consumes its initialization frame. Held Confirm does
not repeat. Nested confirmations and chest-full warnings keep ownership of input;
Back takes priority over a simultaneous action. No new help panel or game prose
is added.

Only `StashInventory.step` (4903), `StashChest.step` (4931), `ItemInfo.step`
(4909) and `ItemInfo.canStepParent` (4910) change. The native transfer, swap,
discard-confirmation, save and constructor routines remain byte-identical.
Combat, audio, global keyboard mapping and the skill tree are unchanged.

## Preparation and checked scope

Use PowerShell 7.2 or later and a new private output path:

```powershell
./Prepare-StashActions.ps1 -PrivateGameFile /private/ddd-altar.swf -OutputFile /private/ddd-stash.swf
```

| Identity | SHA-256 |
| --- | --- |
| Accepted menu input, 28,620,982 bytes | `0dbeb95bea2ad0d64cfb6617a79ff210c15a13183d17e05fc88bcde573fe0b91` |
| Stash candidate, 28,621,088 bytes | `df2b4af61a382e112eab5fd7e02db17f562325068621b6bb598fa0e9e9029804` |

The standalone preparer reproduces the privately assembled candidate exactly.
Whole-file reversal recovers the input. Parsed ABC comparison confirms that only
the four bodies and ItemInfo's local-register count differ; constants, assets
and other metadata are unchanged. Branch boundaries and stack/scope bounds pass.
Actual emitted instructions pass 135 focused scenarios covering empty slots,
panel creation, fresh/held Confirm, direction selection, Back priority, fading,
unexpected child structures and nested modal ownership. Display and native event
callbacks in this check are stand-ins, so it does not prove real transactions.

## Native validation

After Himan reconnected the Brick on October 26, four silent runs started through
the ordinary NX Tools entry, using the accepted `4db2a603...` runtime and a copied
profile. The agent inspected framebuffer captures after actual controller input.

| Check | Observed result |
| --- | --- |
| Item actions | Confirm and Inspect open the original item panel with visible Move and Discard buttons. Directions change the steady highlight. Empty chest slots ignore Confirm. |
| Transfers | Equipment moves to the chest and back; an item moves from chest to inventory. A one-second Confirm hold performs one transfer without reopening the panel. |
| Discard and Back | The original confirmation appears. Back cancels to item information; another Back closes it. Confirm removes exactly the selected item on the disposable profile. Leaving the stash returns to the map. |
| Capacity | A separate full-chest fixture opens the original warning when storing equipment. Direction input does not change selection behind it; Confirm dismisses it once. Discarding one chest item makes room, and a subsequent transfer fills that slot. |
| Equipment swap | Retrieving a different equipment item replaces the carried equipment and returns the old equipment to the same chest slot. No gold changes. |
| Save/reload | Ordinary restart shows the first run's transferred equipment and discarded item state. A later restart shows the full chest with the swapped equipment and newly stored ring in their exact slots. Parsed copied saves agree. |
| Ordinary play | The same candidate reaches the map, enters Infested Sewers, renders the introductory sequence and practice encounter, applies attack damage/XP, and opens/resumes Pause. This bounded pass does not establish a new floor transition or campaign completion. |
| Quit | All four Start+Select exits return to NX in 1.23–1.47 seconds and release the Weston mount. No new AVM exception or runtime panic was found on these paths. |

The separate cleanup pass inspected the settled empty inventory, full chest,
item actions and return to map after restart. Existing labels fit at the Brick's
1024x768 resolution. No extra help panel, duplicate controls, game prose or
decorative effects were added. The original confirmation and warning layouts
remain. Screenshots and automated input do not establish physical feel or human
acceptance; Himan has not yet tried this stash revision.

Private runs: `run-20261026-231327-15780`, `run-20261026-232142-27037`,
`run-20261026-233306-23212` and `run-20261026-234237-22847`.
Captures, fixtures, saves and generated movies remain outside this repository.
The full cached logs still contain font fallback and ALSA POLLERR diagnostics;
audio callback reports continue afterward. These muted runs do not establish
whether a dropout was audible. The existing human audio acceptance is retained,
without claiming that the logs are error-free or that sound was retested.

## Device handoff

The interrupted earlier restoration was verified and completed on reconnect.
After the checks, the smoke entry was restored before installing the stash movie
in untimed Tools → DDD Play Test with normal audio and the canonical human profile.
The canonical save remains byte-identical to its pre-test backup. No disposable
profile was promoted. The accepted runtime, audio configuration and quick quit
are retained. Private installation identities and cleanup evidence are recorded
in `stash-native-20261026/NATIVE-VALIDATION.json` outside this source repository.
