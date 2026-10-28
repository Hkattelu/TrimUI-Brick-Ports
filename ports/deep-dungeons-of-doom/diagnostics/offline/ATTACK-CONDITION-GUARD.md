# Attack condition compatibility guard

The current private save has two historical achievement condition values that
refer to a plain object instead of a vector. Each attack causes repeated typed
argument failures while evaluating those conditions. The game's caught-error
path returns false, but repeatedly formats and reports stack traces first.
Native timing attributes most of the remaining attack logic pause to that work.

`Prepare-AttackConditionGuard.ps1` accepts only the preserved private play movie
with SHA-256 `7406fc2cb24c5b2faf218797b1d6fcc6690fb8522c6f0bc7daf63853ad141d05`.
It changes one private membership operator's first parameter to Object and adds
a vector type guard. Invalid values return false directly. Valid vectors run the
original byte-identical comparison loop. Combat, animation, audio, controls,
save methods and game text are unchanged. It does not reconstruct missing
historical values or claim complete save compatibility.

The helper writes only a new private SWF and its report, outside this repository
or an extracted package. It refuses unknown inputs, existing outputs and linked
paths. It does not install, launch, publish or alter the input or any save.
Expected result: 28,620,972 bytes, SHA-256
`8952b8ca7b5da2be30c18d6eab2bf33c757a9528d17e6bf6270a6413253c551e`.

Independent private bytecode inspection verifies the parameter/body-only change,
whole-file reversal, unchanged original branches and loop, and stack/scope/CFG
bounds. The helper's output matches that inspected movie exactly.

The original `ConditionGuardProbe.as` under `../runtime/ruffle-core` compares the
old caught-error result with the guarded result for 14 cases: matching/missing
wildcard vectors, string conversion, null elements, Object/String vectors, an
empty vector, plain objects, arrays, dictionaries, null/undefined and scalars.
All 14 pass in the existing headless Ruffle test runner. This fixture contains no
game assets or game code. Compile it with `BuildConditionGuardProbe.java`, using
FFDec and `playerglobal32_0.swc` as described for the neighboring AMF fixture.
The three arguments are source directory, new private output SWF and playerglobal.
The compiled fixture is 2,085 bytes with SHA-256
`ca1f20d4646ac23815915f6db53c850a2436cadaba7aa732abeab0f923e3594e`.

The native guarded diagnostic removes the repeated coercion errors and reduces
attack logic spikes substantially; measurements and limitations are in
`../runtime/ruffle-core/ATTACK-HITCHES.md`. A first-use rendering spike remains.
The normal build passed two silent launches through NX Tools using a copy of the
human save. Combat and the settled scene were inspected at 1024x768; the second
launch loaded the copied profile's saved values. Start+Select returned to NX in
about 1.3 seconds in both runs, and the canonical profile hashes stayed unchanged.
These checks do not establish physical attack feel or complete save correctness.
Physical attack feedback remains pending. Packaging is deferred until attack feel
is accepted.
