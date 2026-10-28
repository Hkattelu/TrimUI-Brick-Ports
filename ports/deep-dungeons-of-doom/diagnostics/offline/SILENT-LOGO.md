# Silent logo diagnostic

This probe addresses a startup dependency on the audio playback clock. It does
**not** fix audio. Use it only for explicitly silent diagnostic runs.

`LogosScreen.onAdded` sets a wall-clock deadline 500ms after the logo is added to
the stage. Its step method then starts a sound and waits until that sound's
position reaches 2.16 seconds. `Main.step` returns while the logo reports that it
is still running. When the audio position stays at zero, the logos remain on
screen even though Starling has initialized.

The logo code also intentionally draws random horizontal colored rectangles and
toggles a glitch image according to sound position. Those effects have a source
explanation; their appearance alone does not establish a rendering defect. Exact
rendered fidelity still needs comparison.

Use PowerShell 7.2 or later. `Prepare-SilentLogoProbe.ps1` accepts the private
keyboard-menu probe or the later normal LocalBack/Up-wrap candidate:

```powershell
./Prepare-SilentLogoProbe.ps1 -KeyboardMenuGameFile C:/private/ddd-keyboard-menu.swf -OutputFile C:/private/ddd-silent-logo.swf
```

| Variant | Input SHA-256 | Output SHA-256 |
| --- | --- | --- |
| Keyboard menu | `c92867d7cdf6e86652562889d46641b4ff228feae042ce4b6cb8ca57161d4ce7` | `242fc26d5253c2bb91d3919bb9b0fc77788e1505917b912a6f1ba4719160f392` |
| LocalBack/Up-wrap | `dfe37c79e17dc386cba90c7047b208d9a761b8ea173f7a59a4948934d52f1907` | `27a38d47c908fa03c384f448e8807a9bc75e4f69e731898d4e749a13e394c824` |

The second output is the input expected by the silent
[Encyclopedia Back correction](ENCYCLOPEDIA-BACK.md). The
[complete candidate preparer](../../PREPARE-GAME.md) performs these steps in order.

It makes two same-width instruction changes:

| Method | Instruction offset | Input file offset | Before | After |
| --- | ---: | ---: | --- | --- |
| LogosScreen.onAdded (790) | 204 | 28270610 | `25 f4 03` | `25 e4 14` |
| LogosScreen.step (792) | 30 | 28271107 | `5d 84 03` | `27 48 02` |

The table shows the keyboard-menu layout. In the LocalBack/Up-wrap layout, both
file offsets are 21 bytes later: 28270631 and 28271128. The instructions, method
headers and relative instruction offsets are checked in both variants.

The first changes the deadline from 500ms to 2660ms, retaining the initial delay
plus the original 2.16-second completion threshold as a wall-clock interval.
The second returns false after that deadline, before the sound is created.
Before the deadline, the original conditional branch still returns true.
The sound field remains null: its only assignment was in the now-unreachable
sound-start block. `LogosScreen.dispose` only removes a resize listener and does
not dereference that field.

The early return starts with an empty operand stack; `pushfalse` supplies the
Boolean consumed by `returnvalue`, followed by a padding `nop`. Instruction
widths and later branch addresses stay unchanged. The onAdded and step method
sizes remain 245 and 262 bytes. Exactly five bytes differ in the whole movie.

`Main.step` keeps its existing behavior after the deadline: count down its fade,
dispose and remove the logo, then start Starling's frame loop. Logo assets,
viewport code, global PC identity, menu changes, offline startup, and all other
movie bytes remain unchanged. The logo's sound and audio-timed glitch animation
are deliberately absent from this silent diagnostic.

The helper rejects unknown input hashes, existing output/report files, source or
package output locations, and reparse-point paths. It checks both instruction
contexts and the exact changed-byte count, then restores those bytes in memory
to recover the entire input hash. It writes a private SWF and a provenance report.

For the original keyboard-menu candidate, PowerShell parsing, refusal checks for
existing output, unknown input, source
output and wrong extension, and FFDec reparsing passed. Independent review
confirmed all five changed byte positions, the 2660ms value, the early-return
stack, and the preserved branch to the pre-deadline true return.

The extended helper reproduces both frozen private outputs byte for byte. The
keyboard-menu movie remains 28,620,575 bytes and the LocalBack/Up-wrap movie
remains 28,620,670 bytes. Independent whole-file reversal restores both inputs;
six focused refusal cases leave their inputs and existing outputs unchanged.
Both output hashes are checked before creating a new file. The same five
instruction-byte changes apply, so this preparation extension requires no new
gameplay test and adds no new rendered evidence.

Menu controls and gameplay require their own tests. No audio repair or
playable-port completion is claimed. Keep
the generated game private; only the original helper and these functional notes
belong in the source package.
