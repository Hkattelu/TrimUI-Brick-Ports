# Dungeon shop button candidate

`Prepare-DungeonShopButtonsProbe.ps1` accepts the exact normal or silent-logo
stash candidate and creates a new private movie. It refuses other inputs,
existing outputs or reports, symbolic-link paths, and output inside the source
checkout or extracted package. Purchased game content remains private.

In a settled dungeon shop, Left skips the current offer and Enter requests a
purchase. Skipping uses the existing game action: it rerolls the offer, spends
one unit of finite stock, and can increase the price of later offers. It is not
reversible browsing. Enter opens the existing confirmation; Enter confirms and
Escape cancels. Prices, stock, equipment swaps and saves retain their existing
implementations. No new game text or hints are added.

Only `DungeonShop.step` (method 1676) changes. Its superclass step, shopkeeper
animation and closed-shop check still run. An 18-byte insertion then requires
the encounter's existing `arrived` property and a false result from
`dungeon.hasLevelUpScreenOpen()`. The latter covers both level-up and fade-out.
This prevents the shop from reacting while a floor is entering or while Left
selects a level-up choice. The game's dungeon marks an encounter arrived after
the middle layer becomes ready; the next update can accept shop input.

The two local action consumers become the existing `LEFT` and `CONTINUE` events.
Space and C keep their dungeon actions and are not shop bindings. Combat key
polling belongs to the current floor's encounter, so a settled shop does not
also run the monster encounter's attack or defend handler. The existing modal
purchase confirmation suppresses the parent dungeon step.

The raw insertion changes the method code length from 70 to 88 bytes. It updates
the SWF length, containing DoABC length, and the existing closed-branch target.
All other original relative branches shift with their destinations. No constant
pool, other method body, exception table, method trait, local count, scope depth
or maximum stack changes. Removing the insertion and restoring the six changed
fields must recover the complete input hash.

Prepare a new file in a private directory with PowerShell 7:

```powershell
./Prepare-DungeonShopButtonsProbe.ps1 -StashGameFile /private/ddd-stash-buttons.swf -OutputFile /private/ddd-dungeon-shop-buttons.swf
```

The adjacent JSON report records the hashes and changed sites. Output is
28,620,593 bytes. Independent parsing must check instruction boundaries, stack
flow, all other method bytes and constants, followed by a fresh decompilation.

Both variants pass independent FFDec parsing, whole-file reverse recovery,
comparison of every other method body and all serialized ABC data, and a
branch/stack/scope analysis. A small interpreter over the actual patched
instructions checks all 32 combinations of closed, arrived, level-up, Left and
Enter. Fresh exports of the modified class agree between the two variants.
Refusal checks preserve existing inputs, outputs and reports; a repeat produces
the same hash.

Status: mechanically checked private candidate. No game execution, rendered
review, physical-button check or save reload is claimed. Device checks
must cover arrival input, a settled shop, skipping the last offer, purchase and
cancel, insufficient funds, level-up overlap, quit/return and save reload. This
candidate is not selected automatically by the ordinary installer.
