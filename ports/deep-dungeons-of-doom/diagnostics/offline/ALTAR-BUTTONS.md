# Skill-tree button adaptation

On October 26, Himan accepted combat with the attack-fix candidate, then reported
that the skill tree opened but only Back worked. The private PC movie gates
initial skill selection and directional navigation behind its OUYA platform
check. Its buy, activate, career and stats actions also use enums that the PC
keyboard handler never emits.

`Prepare-AltarButtons.ps1` accepts only the preserved attack-fix movie with hash
`8952b8ca7b5da2be30c18d6eab2bf33c757a9528d17e6bf6270a6413253c551e`.
It writes a separate private movie and report. Unknown input, existing output,
linked paths and output inside the source checkout or package are refused.
Generated movies contain purchased content and must remain private.

| Existing keyboard mapping | Skill-tree action |
| --- | --- |
| Arrows | Select a skill; the existing selector and scrolling follow it |
| Return | Buy an available skill, or activate a purchased skill |
| Space | Cycle through unlocked characters, once per fresh press |
| C | Show the selected character's stats |
| Escape | Close stats, or return from the skill tree to the map |

Existing prices, unlock requirements, purchase/activation routines and saves are
retained. The original purchase routine also activates the purchased skill.
Locked skills remain inspectable but have no buy/activate action. A successful
or failed action consumes that HUD update. Directional input is blocked when a
modal opens during the same parent update, and stats preserve the skill scroll
target. The original PC art, text and pointer buttons remain. No combat, global
keyboard mapping, platform identity, runtime or audio changes are included.

Only four method bodies change: Scene's contextual Back getter (242), initial
skill selection (5412), skill navigation (5413), and skill-tree HUD input (5451).
Method metadata and constant pools remain unchanged. The output grows ten bytes
to 28,620,982 bytes with SHA-256
`0dbeb95bea2ad0d64cfb6617a79ff210c15a13183d17e05fc88bcde573fe0b91`.

The first hardware trial exposed an error in the new modal guard: it read the
`hasSubScene` function object instead of calling the method, which blocked all
directions. The corrected guard calls `hasSubScene()` and retains the same
method length. On the corrected movie, native Brick checks passed directional
selection and scrolling, character cycling, stats/Back, two purchases, changing
the active skill, insufficient-funds dismissal and purchase persistence after
restart. These checks used a silent, copied profile; physical feel is still
awaiting Himan's review.

Private independent preparation and the PowerShell helper produce identical
bytes. Whole-file reverse recovery, four-method-only parsed identity, branch
destinations, stack/scope bounds and fresh decompilation are checked. The output
safety checks cover unknown input, existing output and protected source output.
These establish preparation correctness; hardware interaction and human feel
remain separate gates.

The focused Brick check uses an isolated copy of the latest human save and silent
audio. It covers visible selection, all directions and scroll limits, character
cycling, stats and Back, locked/available/purchased skills, purchase/activation,
the insufficient-funds modal, reload and ordinary quit. Purchases must affect
only the copied profile. Inspect the actual menu after interaction and perform
a separate cleanup pass before preparing the untimed human candidate.
