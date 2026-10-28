# Stash button candidate

`Prepare-StashButtonsProbe.ps1` adds a small private candidate after the existing
shop/extras button candidate. It accepts only the two recognized exact input
hashes, refuses existing outputs or reports, and refuses output inside this
source checkout or extracted package. Purchased game files remain private.

The proposed controls within the stash are:

| Input | Action |
| --- | --- |
| Left/Right | Select either carried item, or a chest column |
| Up/Down | Select a chest row |
| Space | Switch between inventory and chest |
| Enter | Transfer the selected item |
| C | Open the existing item information panel |
| Escape | Close information, or leave the stash |

Only five method bodies change, through eleven fixed-width edits. The patch
initializes the existing selectors, enables the stash's own keyboard handling,
and changes local action consumers to the keyboard actions already emitted by
the game. It leaves the global platform, keyboard translation, constant pools,
game text, item-transfer implementations, saves and confirmations unchanged.
The existing PC arrow buttons remain. OUYA button hints are skipped.
The selectors are the game's existing Quad objects. They sit above item docks
and are not explicitly made untouchable, so retaining pointer handlers does not
prove that pointer hits still reach every item. The Brick button path is the
candidate's scope; pointer behavior needs a separate check if it is required.

Space is handled only while the page is centered and no subscene is open. It
hides both selectors and starts the existing scroll. The changed branch then
skips the old panel's step in that update, so a simultaneous transfer or inspect
press cannot act on the old selection. The existing scroll completion assigns
one focused panel and reveals that panel's selector. Input during scrolling
does not reach either panel's step. Bare `ItemInfo.canStepParent` still returns
true, allowing the stash's existing Back branch to close it with Escape. The
following `hasSubScene` guard returns before paging or focused-panel dispatch,
so C does not reopen information and Space does not switch the page underneath
it. No input behavior is added to the information panel itself.

Discard is deliberately outside this patch. The existing PC detail panel has
Move and Discard callbacks, but making those buttons accessible needs separate
input routing and its own confirmation checks. No delete shortcut is added.
DungeonShop controls also remain separate because its parent dungeon consumes
Space and C for other actions.

Prepare a new file in a private working directory with PowerShell 7:

```powershell
./Prepare-StashButtonsProbe.ps1 -ShopExtrasGameFile /private/ddd-shop-extras-buttons.swf -OutputFile /private/ddd-stash-buttons.swf
```

The adjacent JSON report records the input/output hashes and all changed sites.
The output stays 28,620,575 bytes; exactly 28 bytes differ. Reversing those sites
must recover the complete input hash. A separate parser check must confirm the
unchanged method headers, instruction boundaries and jump destinations.

Mechanical checks passed for both recognized input variants: exact whole-file
recovery, five changed method bodies, unchanged headers and all other method
bytes, valid branch destinations, selector initialization, retained PC arrow
construction, and the old-focus/subscene guards. Twenty-four refusal checks
covered unknown input, existing output/report, protected output locations,
header/hash mismatch and every instruction/context guard. An independent
source review and fresh decompilation found no blocking control-flow issue.

No Brick run, rendered review, save reload or physical-button validation is
claimed. The device gate must cover both panels, empty and occupied slots,
transfers with a full chest,
information open/close, paging during simultaneous input, quit/return and save
reload. The candidate is not selected automatically by the ordinary installer.
