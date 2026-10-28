# Menu Up-wrap diagnostic candidate

`Prepare-MenuUpWrapProbe.ps1` corrects the adapted ButtonMenu's unsigned selection
arithmetic. Moving Up from option zero currently stores 4294967295 before
normalization. With three options, that leaves option zero selected. The candidate
adds the option count before subtracting one, so Up wraps to the last option.
Down, simultaneous direction ordering, Continue callbacks and empty-menu behavior
remain unchanged.

Both ordinary variants are mechanically checked diagnostic candidates, not the
selected installation. A private composition of the normal variant with existing
menu/frame traces has now passed a bounded Brick test: Up wrapped `0 -> 2` on
Pause and `0 -> 3` on the main menu. Down wrapped `2 -> 0` on Pause. Six short
direction taps each moved once; a deliberate hold repeated and stopped on release.
The trial used the separate pipeline-cache runtime and bounded input draining.
It does not establish that this arithmetic change fixes delayed releases: the
earlier slow renderer produced extra repeats that require separate treatment.
See the [native results](../runtime/ruffle-stage3d/README.md#button-navigation-trial).
Recognition by the private installer permits explicit preparation; it does not
select or install either candidate.

Use PowerShell 7 and a new `.swf` path in an existing private directory:

```powershell
./Prepare-MenuUpWrapProbe.ps1 -PrivateGameFile /private/ddd-local-back.swf -OutputFile /private/ddd-menu-up-wrap.swf
```

The helper accepts only the two exact [LocalBack](LOCAL-BACK.md) predecessors.
It refuses existing outputs/reports, linked paths and output inside the source
checkout or extracted package. It rehashes the input before and after preparation,
checks the exact output hash, and reverses the patch to recover the entire input.
Generated movies and reports remain private; no game assets are packaged here.

| Predecessor | Input SHA-256 | Output SHA-256 | Output bytes |
| --- | --- | --- | --- |
| LocalBack | `6965ee58aedd765408f76c4ccc74f1c5a794c7d8a77d8e3608480fae02b87ce2` | `dfe37c79e17dc386cba90c7047b208d9a761b8ea173f7a59a4948934d52f1907` | 28,620,670 |
| Discard LocalBack | `776f7569add97f1507e47e593a415e174334d1976a52e54ce8c7208cc1873b79` | `1cee961e1aee97345a9547ac0e55d03ad4ba6a6033b594e76ec1bfb5d24301da` | 28,620,888 |

Only method 4538 changes, adding eight code bytes. No constant, other method,
stack/local declaration, input mapping, save routine or game text changes.
Independent parsing checked branch boundaries, stack/scope balance, all other
ABC data and whole-file reversal. An interpreter of the actual before/after
bytecode passed 992 cases per variant: option counts zero through six and larger
counts, boundary/interior selections, and every combination of fresh/repeating
Up, Down and Continue. The normal output was decompiled and inspected.

Before selecting either ordinary candidate, check the uninstrumented composition
and a confirmation cancellation. The traced normal composition has rendered
navigation evidence; the discard composition has not. Existing LocalBack and
discard validation requirements still apply. These checks do not establish
physical input feel or complete menu compatibility.
