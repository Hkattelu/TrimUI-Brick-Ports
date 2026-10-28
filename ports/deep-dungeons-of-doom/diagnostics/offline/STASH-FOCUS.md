# Stash focus correction candidate

The original `StashInventory.focused` setter checks whether the selected slot
is empty, then loads the other slot and discards that value. It never assigns
the selection. Returning an item from the chest into the other empty inventory
slot can consequently leave the highlight hidden and item actions unavailable
until Left or Right selects the filled slot.

`Prepare-StashFocusProbe.ps1` accepts only the exact normal or silent-logo
guarded DungeonShop candidate and creates a new private movie. It replaces that
one setter's empty-slot branch with an assignment to the other slot and updates
the existing selector's x and y. Null selection/selector guards remain, filled
selections remain unchanged, and visibility still requires both focus and a
nonempty selected slot. When both slots are empty, the selected identity can
alternate; both remain hidden and nonactionable.

The method grows from 86 to 115 bytes, replacing 27 bytes with 56. The existing
maximum stack of three, two local registers and scope depths stay unchanged.
Only the two branches crossing the replacement and three containing length
fields need adjustment. There are no new fields, constants, text, input rules,
save changes or confirmation changes. Earlier candidates remain preserved.

Run with PowerShell 7 and a new private output path:

```powershell
./Prepare-StashFocusProbe.ps1 -DungeonShopGameFile /private/ddd-dungeon-shop-buttons.swf -OutputFile /private/ddd-stash-focus.swf
```

The helper refuses unknown inputs, existing output/report paths, symlink paths
and output inside the source checkout or extracted package. The adjacent JSON
records exact hashes and changed sites. Output is 28,620,622 bytes. Reversing
the replacement and five modified fields must recover the complete input hash.

Both recognized variants passed whole-file reverse recovery and serialized-ABC
comparison after restoring the one changed method. All other method bodies,
constants and metadata remain identical. The parsed control-flow check verifies
branch boundaries, stack balance and the unchanged stack/scope limits.

A small interpreter executes the actual parsed setter over 48 combinations of
selected slot identity, null selection/selector, empty/filled slots and focus
true/false, checking the resulting selection, x/y and visibility. The candidate
passes all 48; the original setter fails eight. Fourteen refusal/context checks
passed, and an independent review reran both variants and inspected a fresh
decompilation. These are mechanical checks, not game execution.

The device gate must cover both inventory slot identities, empty/filled
transitions after chest transfer, selector position/visibility, information, save reload and
ordinary quit/return. No rendered, device or physical-input validation is claimed.
This candidate is not selected automatically by the ordinary installer.
