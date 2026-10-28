# Private WorldMap button probe

`Prepare-WorldMapButtonsProbe.ps1` enables the game's existing discrete map
navigation for a recognized private keyboard-menu movie. The Brick needs no
analog stick or emulated mouse for these paths. This is a static compatibility
experiment; rendered device checks and the cleanup pass remain required.

Run the helper with `-KeyboardMenuGameFile` pointing to the output of
`Prepare-KeyboardMenuProbe.ps1`, or its recognized silent-logo diagnostic
variant. Choose a new `-OutputFile` ending in `.swf` in a private directory
outside this repository or an extracted source package. Both the movie and its
JSON report must be absent. Keep all generated movies private.

## Controls and scope

| Screen | Keyboard action delivered by the runtime | Result |
| --- | --- | --- |
| World map | Up, Down, Left, Right | Follow the map's existing directional links |
| World map | Enter | Open the selected dungeon's character/entry panel |
| World map | C | Focus the existing stash/extras side buttons |
| Side buttons | Up, Down, Enter | Select and invoke the existing button callback |
| Side buttons | Space | Return focus to the map |
| Dungeon entry panel | Left, Right | Select the previous/next character |
| Dungeon entry panel | Enter | Invoke the existing dungeon entry action |
| Dungeon entry panel | Space | Close the panel and return to the map |
| World map or entry panel | Escape | Retain the existing PC main-menu route |

The current private runtime binds the D-pad to the arrows, Start to Enter,
Select to Escape, logical `north` to C, and logical `west` to Space. Confirm the
physical face-button labels against the selected NX Redux layout before writing
the final player controls. The new C/Space aliases apply only in WorldMap and its
entry panel; combat and item controls are unchanged.

Options already uses `ButtonMenu`, enabled by the preceding keyboard-menu
patch. Its existing Up/Down handling cycles through every option, including
the two-column PC layout, and Enter invokes the matching callback. Escape
returns from Options. `setOptions` resets the selected item and repositions the
highlight. No additional Options bytes are changed here. Device validation
should check that highlight movement is clear and every option is reachable.
Use a reversible option when testing persistence; Reset Game is destructive.

Stash, extras, shops and later nested dialogs are outside this bounded patch.
Their entry buttons are reachable in the map logic, but their full interaction
paths have not been certified. The entry panel's existing PC text may still
describe pointer actions; rendered review must check whether a contextual hint
is needed. No dialogue or replacement text is added by this experiment.

## Exact changes

Seven instruction sites change nineteen bytes in three method bodies. File
length, method lengths and all other bytes remain unchanged.

| Method | Instruction offset | Change |
| --- | ---: | --- |
| WorldMap constructor, 2211 | 630 | Replace the OUYA-only comparison branch with two pops and two nops, initializing its existing navigation fields |
| WorldMap constructor, 2211 | 972, 982 | Replace the obsolete shoulder hints' x-coordinate assignments with `visible=false`; retain both children and their disposal lifecycle |
| WorldMap step, 2225 | 177 | Replace the OUYA-only comparison branch with two pops and two nops, enabling existing map/button handling |
| WorldMap step, 2225 | 209 | Use the existing C action (`OPEN_STATS_SCREEN`) to focus side buttons |
| WorldMap step, 2225 | 305 | Use the existing Space action (`USE_ITEM`) to return to the map |
| MapPointSelector step, 4631 | 96 | Use Space to close the dungeon entry panel |

The two removed comparison branches consume the same two stack operands as
their replacements. The hint replacements still assign one value to one
receiver. Property substitutions retain their original instruction width.
The global platform remains PC. Pointer event-handler methods, purchase flags,
gameplay methods, save methods and the offline bootstrap are unchanged.

WorldMap's `onAdded` OUYA guard at 344 stays intact: its indexed button access
assumes a different IAP-dependent button list. The entry-panel constructor's
OUYA hint guard at 243 also stays intact. Initial map selection, map-point
entry, and the panel's character selection and entry methods were inspected;
they need no additional platform guard changes for this path.

## Source and output identities

| Movie | SHA-256 |
| --- | --- |
| Input keyboard-menu probe | `c92867d7cdf6e86652562889d46641b4ff228feae042ce4b6cb8ca57161d4ce7` |
| Output WorldMap button probe | `28ebdbb520af0613eec692e38c6778b56ce214eaa29ee79187f05bbb461268b5` |
| Input silent-logo keyboard-menu probe | `242fc26d5253c2bb91d3919bb9b0fc77788e1505917b912a6f1ba4719160f392` |
| Output silent-logo WorldMap button probe | `c6b670ddb1d31daefe092fdeba04fb3e6eaa1be6f09aa0a3bd6d692ba12de23c` |

Every movie above is 28,620,575 bytes and remains outside Git. The helper pins
both recognized inputs, guards the rewritten instructions and their operands,
checks the exact changed-byte count, and reverses its changes in memory to
recover the entire original input hash before writing a new file.

## Checks completed on October 25, 2026

Both variants passed a separate FFDec reparse. Every method header and length
was preserved; all remaining branches in the three changed methods still land
on instruction boundaries. The validator confirmed the expected C/Space
properties, hidden-hint visibility assignments, retained hint `addChild` calls,
and unchanged Options, entry/exit, pointer and save method bodies.

Focused refusal checks passed for an existing movie, an existing report,
output inside the source repository, an unrecognized input, and a non-SWF
output extension. Existing output and original input hashes stayed unchanged.
These checks establish bytecode structure and helper behavior, not rendered
navigation, input feel, save compatibility or acceptance by the user.
