# Local Back diagnostic candidate

`Prepare-LocalBackProbe.ps1` lets Escape reach the existing contextual Back
handlers on the adapted stash, world map and map shop. It accepts only the exact
normal stash-focus candidate or its discard successor and writes a new private
movie. Generated game files must stay outside this source checkout or extracted
package. Existing outputs and reports are never overwritten; linked paths are
refused.

Both variants are mechanically checked diagnostic candidates. The normal
stash-focus variant was installed privately on October 25 and rendered the
dungeon and Pause screen. Its targeted map/stash/shop Back actions remain
untested on hardware; the discard successor remains unselected. Recognition by
`Prepare-PrivateInstall.ps1` only allows explicit private preparation; it does
not select or install either variant. Silent-logo inputs are not recognized by
this preparer.

## Behavior and limits

The keyboard emits both HOME and BACK for Escape. The game's main update handles
HOME before stepping a scene, so the inherited default can send these menus
straight to MainMenu. This candidate makes `Scene.handlesHomeButton` return true
only for Stash, WorldMap and MapShop. Other inherited scenes still return false,
and explicit overrides remain unchanged.

Existing child-first scene handling then applies:

- Back closes bare stash item information; a later fresh Back returns to the map.
- Back closes Extras without also leaving the map in the same update.
- Back closes a shop purchase panel or cancels its ready confirmation. Existing
  Enter-only acknowledgment boxes still require Enter.
- While the stash/extras buttons have focus, Back returns to map navigation.
  With no panel or button-menu focus, a fresh Back opens MainMenu.

The map-entry panel also accepts fresh Back alongside its existing fresh Space
close action. Its original ACTIVE-state guard and closing animation remain.
Enter, Right and Left retain priority over simultaneous Space/Back. Held Back
does not repeat the close request. MessageBox confirmations retain their
existing Enter-before-Back priority when both arrive together.

Only methods 242 and 4631 change. No input mapping, platform identity, game text,
item transaction, save routine or confirmation callback changes. This preserves
the existing modal behavior; it does not make Escape dismiss every dialog.

## Preparation and evidence

Use PowerShell 7 with a new output path in an existing private directory:

```powershell
./Prepare-LocalBackProbe.ps1 -PrivateGameFile /private/ddd-stash-focus.swf -OutputFile /private/ddd-local-back.swf
```

The JSON report records the predecessor and result, the two changed methods and
the remaining validation limits. The input is rehashed before and after
preparation. Reversing the two replacements and their length fields must recover
the complete original input.

| Predecessor | Input SHA-256 | Output SHA-256 | Output bytes |
| --- | --- | --- | --- |
| Stash focus | `aaca5f5967b41348e116036764a93152921b1c0c321098ef14fc047672631b98` | `6965ee58aedd765408f76c4ccc74f1c5a794c7d8a77d8e3608480fae02b87ce2` | 28,620,662 |
| Discard successor | `cff4cd4454ea3836ffccea924c74102321f8daa2e6e0bdc946b4d16bed3c4718` | `776f7569add97f1507e47e593a415e174334d1976a52e54ce8c7208cc1873b79` | 28,620,880 |

Each output grows by 40 bytes: the getter grows from 4 to 25 code bytes, the
selector from 113 to 131, and the selector's encoded code length gains one byte.
No constants or body metadata are added. Independent parsing verified valid
branch boundaries and balanced stacks/scopes, all other method bodies and ABC
metadata unchanged, the type gate across all 693 game classes, and all 32
combinations of the selector's five actions. Actual output decompilation matched
the intended routing. The public helper reproduced both hashes above and passed
output-safety refusals for the checkout, an extracted package, existing files,
unrecognized inputs and linked paths.

Before treating either candidate as validated, test ordinary rendered navigation, submenu
Back, confirmation cancellation and save/reload on the Brick. The discard
variant also retains the [discard candidate's validation requirements](STASH-DISCARD.md).
Mechanical checks do not establish physical input feel, rendered quality or
successful gameplay.
