# Encyclopedia Back candidate

The adapted Escape mapping sets both HOME and BACK. Encyclopedia inherits a
false `handlesHomeButton` result, so the global HOME handler replaces it with
MainMenu before its local Back handler can run. When opened from Pause, its
intended destination is the retained dungeon with Pause still attached. The
incorrect detour can leave that dungeon referenced while showing MainMenu.

`Prepare-EncyclopediaBackProbe.ps1` extends the existing LocalBack predicate to
include Encyclopedia. Only method 242 changes, from 25 to 33 code bytes. The
three existing scene predicates, other inherited fallback, explicit overrides,
global dispatch, Back callback, save code and game text remain unchanged.

Use PowerShell 7 with an exact private [Up-wrap](MENU-UP-WRAP.md) predecessor:

```powershell
./Prepare-EncyclopediaBackProbe.ps1 -PrivateGameFile /private/ddd-menu-up-wrap.swf -OutputFile /private/ddd-encyclopedia-back.swf
```

| Variant | Input SHA-256 | Output SHA-256 |
| --- | --- | --- |
| Normal Up-wrap | `dfe37c79e17dc386cba90c7047b208d9a761b8ea173f7a59a4948934d52f1907` | `1c69ba3ab597452348ab44ee5d372c1ba7689dd91d8aff8091364703f6e07233` |
| Silent-logo Up-wrap | `27a38d47c908fa03c384f448e8807a9bc75e4f69e731898d4e749a13e394c824` | `a308ea6466305b6e9a553387f67c8f8b317edf0d0fa57f09bb47a1e0b537f3f7` |

Both outputs are 28,620,678 bytes. The preparer verifies exact input/output
hashes, recovers the complete original by reversing the change, and rechecks the
input before writing a new output. It rejects linked paths, existing output or
report files, unsupported predecessors and output inside the source package.
It needs no decompiler. It neither installs nor launches the result. Generated
movies and reports remain private; the source archive contains no game assets.

Independent review checked the complete byte reversal, single changed ABC body,
unchanged constants/headers, all branch targets and stack/scope balance. Thirteen
effective scene-dispatch cases retained the existing behavior except Encyclopedia.
The actual emitted getter was decompiled and inspected. The standalone helper
reproduced both reviewed outputs exactly, and its focused refusal checks passed.

On October 25, run `run-20261025-164217-16346` tested the silent output with the
cache-enabled `b381ea22...` runtime and bounded input draining. Unlike the earlier
button trial, this movie has no added menu/frame traces. The reviewer inspected
Pause -> Encyclopedia -> Back -> Pause, then a fresh Up/Return -> the same
visible sewer and HUD. One Back press did not also resume. A later Up wrap selected
Exit Dungeon; Return opened its confirmation, Escape cancelled it, and a separate
Escape resumed. No exit was confirmed. No AVM2 exception was logged on these
returns. Existing font, locale and intentionally unavailable audio diagnostics
remain; this was not an audio test.

A guarded TERM request ended game and parent 143. The exact ordinary four-file
set was restored, all 461 manifest entries passed, owned display resources were
released and NX was inspected afterward. This is a tested candidate, not the
selected ordinary installation. MainMenu-origin Encyclopedia return, broader
shop/stash coverage, later progression saves and physical input feel still need
validation. The preparer's report describes a newly prepared file as unexecuted;
it does not infer device acceptance from an earlier run of the same hash.
