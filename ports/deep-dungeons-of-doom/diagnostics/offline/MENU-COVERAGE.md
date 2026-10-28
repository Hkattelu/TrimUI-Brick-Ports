# October 26 Brick menu checks

The private skill-tree movie is
`0dbeb95bea2ad0d64cfb6617a79ff210c15a13183d17e05fc88bcde573fe0b91`.
It uses the unchanged, human-accepted attack runtime
`4db2a60317634a43c81b510ec7ac6c3db6644240defcca13fbad20a2d1317875`.
The adaptation is described in [ALTAR-BUTTONS.md](ALTAR-BUTTONS.md).

Tests started through NX Redux's ordinary Tools launcher on the original Brick.
Both corrected-candidate runs used a separate copied profile and runtime volume
zero. Framebuffer captures were inspected after actual button input. The user's
canonical profile was never the test runtime's save directory.

| Area | Observed result |
| --- | --- |
| Skill-tree selection | Initial selection is visible. Up/Down changes tiers and scrolls; Left/Right changes columns. Held navigation reaches upper and lower selections without leaving the tree. |
| Locked skills | Locked-tier and locked-column descriptions can be inspected. Confirm does not spend gold or unlock them. |
| Characters and stats | Space cycles the two unlocked careers. A one-second hold changes career once. C opens stats; Escape returns to the same selected tier and scroll position. |
| Purchases and activation | Two first-tier skills cost 50 gold each. Gold changes from 118 to 68 to 18. Purchasing autoactivates the skill through the original routine; Return reactivates a previously purchased sibling without charging again. |
| Insufficient funds | An available 200-gold skill opens the original warning. Directions do not change selection behind it. Return dismisses it with selection and gold retained. |
| Skill save/reload | After quit and ordinary restart, the tree still shows 18 gold, the selected active skill, and the purchased inactive sibling. Parsed copied-save data agrees. |
| Encyclopedia categories | Careers, Monsters and Bosses are reachable in both category directions, including wraparound. Entry movement updates portrait and description; held scrolling reaches locked entries. |
| Encyclopedia return | Main-menu entry returns to the main menu. Dungeon Pause entry returns to Pause with its selection retained; Resume returns to the same practice-dummy encounter. |
| Options navigation | Up/Down reaches all six choices in row order across the two columns. Return activates; the Back choice and Escape both leave Options. Options belongs to the main menu; the dungeon Pause menu has no Options entry. |
| Options toggles | Music off/on, pixel-perfect no/yes/no and cutscenes no/yes/no update their labels. Pixel-perfect visibly changes the game viewport. Restored settings are visible after restart. Silent tests verify the controls, not audible music output. |
| Fullscreen choice | The original windowed/fullscreen choice toggles its label and returns to its initial state without a blank screen or lost controls. The launcher still owns a fullscreen presentation; a desktop-style window is not expected on the handheld. |
| Reset Game | Escape cancels and preserves copied progress. After purchase/reload checks, Return confirms a reset on that same disposable copy: parsed data shows day zero, zero gold, the initial career/altar, and no purchased skills. The canonical human profile remains unchanged. |
| Quit and cleanup | Start+Select ends each owned run in about 1.5 seconds, releases the Weston mount and returns to the NX Tools menu. No new AVM exception was observed on these menu paths. |

The separate rendered cleanup pass inspected the settled tree, active/inactive
skill states, warnings, category pages and restored Options screen. Existing art,
text and the native selection indicator remain; the adaptation adds no overlay,
duplicate controls or decorative effects. The indicator retains the game's
original blink. Screenshots establish visible states, not physical input feel.

The first trial's modal-guard error was corrected before the above runs. The
corrected native checks are recorded privately as runs
`run-20261026-163606-29466` and `run-20261026-164353-8465`.
Screenshots, saves, logs and generated movies remain outside this source checkout.

This covers the reported skill-tree path and the requested Encyclopedia/Options
audit. It does not certify every nested screen, every encyclopedia entry, new
audio quality, or a full campaign. Combat, audio and the quit chord retain their
earlier human acceptance. Himan subsequently reported that these three screens
"worked pretty well" during ordinary play and accepted this menu pass. His
remaining menu concern was the stash. Its visible action menu subsequently passed
native transactions, capacity handling, save/reload and a separate rendered
cleanup pass, and is installed for private play. Human feedback on that revision
is still open; see [STASH-ACTIONS.md](STASH-ACTIONS.md).
