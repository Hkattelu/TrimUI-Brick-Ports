# Private MapShop and Extras button candidate

`Prepare-ShopExtrasButtonsProbe.ps1` enables the existing button navigation in
MapShop and ExtrasScreen. This is an **unvalidated candidate**, prepared and
inspected statically while the Brick was disconnected. It has not been launched,
rendered or accepted as a working replacement.

Supply `-WorldMapGameFile` with a recognized output from
`Prepare-WorldMapButtonsProbe.ps1`, and choose a new private `.swf` output path.
The helper refuses existing movie/report paths, unknown inputs, already-prepared
inputs and output inside the source repository or extracted package. It does
not modify the input movie. Generated movies contain purchased game content and
must stay private; only original helper source belongs in the source package.

## Controls and remaining scope

The map shop uses Left/Right to select an item, Enter to open its existing
purchase panel, and Escape to leave. The panel already accepts Enter to request
a purchase and Escape to close. Its existing confirmation accepts Enter/Escape.
Prices, inventory room checks, purchase effects and saves are unchanged.

Extras uses Left/Right to select an enabled button, Enter to invoke it, and
Escape to close. Its existing mission screen accepts Enter/Escape. Achievement
and leaderboard callbacks retain their external service dependencies; this
candidate does not make those services available offline.

Stash and the in-dungeon `DungeonShop` remain outside this patch. They have
separate action enums that the PC `KeyboardInput` does not emit. In particular,
`DungeonShop.step` method 1676 tests `DUNGEON_SHOP_NEXT_ITEM` at offset 28 and
`DUNGEON_SHOP_BUY_ITEM` at 53; neither is handled by `KeyboardInput.call` method
2684. This candidate must not be described as fixing every shop or menu.

The original selector Quads are added above the buttons without an explicit
`touchable=false`. They may intercept pointer hits over the highlighted button.
Pointer handlers and the map shop's PC Back button remain present, but pointer
interaction is unvalidated. The Brick review must inspect highlight placement,
button selection, confirmation/cancellation and return paths, followed by the
separate visual cleanup pass. No game text or art is added.

## Exact changes

Five instruction sites change twenty bytes in four method bodies. Every file
and method length remains unchanged, as do all bytes outside these sites.

| Method | Instruction offset | File offset | Change |
| --- | ---: | ---: | --- |
| MapShop constructor 4385 | 712 | 28511450 | `14 3b 00 00` to `29 29 02 02`: initialize its existing selector |
| MapShop constructor 4385 | 771 | 28511509 | `10 3e 00 00` to `02 02 02 02`: also retain the original PC Back button |
| MapShop step 4389 | 12 | 28512082 | `14 21 01 00` to `29 29 02 02`: enable existing navigation |
| ExtrasScreen constructor 4677 | 536 | 28538525 | `14 af 00 00` to `29 29 02 02`: initialize callbacks and selector |
| ExtrasScreen step 4682 | 91 | 28538986 | `14 2b 01 00` to `29 29 02 02`: enable existing navigation |

Each replaced comparison branch consumes two operands; two pops consume the
same operands. The replaced unconditional jump and four nops consume none.
Surrounding platform operands and the map shop's retained Back-button block
are guarded before writing. The global platform stays PC.

The existing scene focus rules prevent Enter from reopening the shop panel
while that panel is active. `Scene.doStep` 241 reads the child's
`canStepParent` at offset 16 and skips parent stepping at 31 when false.
`MapShopPurchaseItem.canStepParent` 5118 and `MissionScreen.canStepParent` 2253
return false. Shop confirmations use the default modal `MessageBox32`, whose
base `MessageBox.canStepParent` 2728 returns the inverse of its modal flag.
WorldMap step 2225 checks `!hasSubScene` at offsets 192–200 before map navigation,
so the Extras screen's input does not also navigate the map. These focus
methods are unchanged; actual interaction still requires device validation.

## Identities and checks

| Variant | Input SHA256 | Output SHA256 |
| --- | --- | --- |
| WorldMap buttons | `28ebdbb520af0613eec692e38c6778b56ce214eaa29ee79187f05bbb461268b5` | `8fe3cbdee3b93524805bc458d29d24461a6867062e7f4d2fade4ff6b8c755908` |
| Silent-logo WorldMap buttons | `c6b670ddb1d31daefe092fdeba04fb3e6eaa1be6f09aa0a3bd6d692ba12de23c` | `1b243770798f494e489b9c47df169b7224d63ae70c5a5ddc1793c98414960849` |

Both outputs are 28,620,575 bytes. Each passed an independent FFDec reparse:
all method headers and unrelated method bytes match the input, exactly twenty
bytes differ at the five permitted sites, and remaining branches land on
instruction boundaries. Fresh ActionScript exports of both variants produced
identical MapShop and ExtrasScreen source, which was read to check control flow
and retained initialization. The scene and confirmation focus methods were
also inspected directly.

Six refusal checks passed: existing output, existing report, unknown input,
already-prepared input, repository output and wrong extension. Preparing the
same recognized input at another absent private path produced the same hash;
existing files remained unchanged. These checks establish preparation and
bytecode structure, not rendering, input feel, audio or save acceptance.
