# Stash discard diagnostic candidate

`Prepare-StashDiscardProbe.ps1` adds an optional controller route to the game's
existing discard confirmation. It accepts the exact normal or silent-logo
stash-focus candidate, or the later silent startup-save candidate, and writes a
new private movie. Generated movies contain
purchased game content and must remain outside this source checkout or extracted
package. Existing movies and reports are never overwritten.

The combined startup-save/discard movie has rendered ordinary dungeon play on
the Brick and is prepared for human testing. Its discard action has not yet been
reached on hardware. The earlier two discard variants remain mechanically checked
diagnostics. `Prepare-PrivateInstall.ps1` recognizes those earlier variants when
explicitly supplied; it does not yet recognize the combined startup-save variant.

## Controls and guards

Select an item, press C to inspect it, release C, then press Space to request
discard. The original modal confirmation opens. Return confirms after its
existing readiness animation; Escape cancels and returns to the stash. Space
still switches inventory/chest when no information panel is open.

The new action requires a centered stash page, fully visible item information,
no nested dialog, a fresh Space press and a non-null focus. Held Return, C or
directions block it, as do Return/C taps in the same frame. The existing
nonempty-item checks remain. Direction guards prevent the focused panel's step
from selecting a different item before opening confirmation. Held Space does
not repeat the request. The existing Back branch retains priority.

ItemInfo retains no item ID or dock reference, so this exact candidate uses a
pinned structural guard: keyboard-created information has three direct children;
the pointer detail panel appends Move and Discard buttons and has five. Only the
three-child form is accepted. Those constructors are unchanged. This condition
must be reviewed again for any other game revision or information-panel change.
It does not add keyboard behavior to the pointer detail panel.

The existing confirmation iterates Return before Escape. Pressing both together
retains that original Return priority. No direct-delete shortcut, confirmation
bypass, global keyboard change, launcher mapping or new game text is added.
Discoverability still needs rendered review.

## Preparation and validation

Run with PowerShell 7.2 or later and a new output path in a private directory:

```powershell
./Prepare-StashDiscardProbe.ps1 -FocusGameFile /private/ddd-stash-focus.swf -OutputFile /private/ddd-stash-discard.swf
```

To add discard to the output of `Prepare-StartupSaveProbe.ps1`, pass that private
movie as `-FocusGameFile` instead. No donor movie or decompiler is required.
The JSON report records the predecessor, result and guard conditions. Every
output adds 218 bytes: the first two variants are 28,620,840 bytes; the combined
startup-save variant is 28,620,963 bytes.

| Variant | Input SHA-256 | Output SHA-256 |
| --- | --- | --- |
| Normal | `aaca5f5967b41348e116036764a93152921b1c0c321098ef14fc047672631b98` | `cff4cd4454ea3836ffccea924c74102321f8daa2e6e0bdc946b4d16bed3c4718` |
| Silent logo | `0d252a37c40967eb02ec4e4c62354b37214134c45f48e77793ef61c418af7c47` | `5759109c2b8d287d8d99cd29c1afd8a3811fd43684f4ca4fcecb50937dba7262` |
| Silent startup-save | `c06c703c96cb1a3af5f006f2cb68a11f0d2d31118e5bb4cbd71d6b2951409f8e` | `7406fc2cb24c5b2faf218797b1d6fcc6690fb8522c6f0bc7daf63853ad141d05` |

Only `Stash.step` (2610), `StashInventory.step` (4903) and `StashChest.step`
(4931) change. The parent gains an appended context guard reached through its
existing subscene branch. The two panel methods consume Space in their existing
discard-request branches. Normal paging skips those branches. Save, transfer,
confirmation and item-information construction methods remain unchanged.

Both variants passed complete input recovery, unchanged serialized ABC metadata
and constant pools after restoring those three methods, valid branch boundaries,
stack/scope checks, and an interpreter over the actual changed bytecode. The
context guard covered held/simultaneous inputs, scrolling, fading, nested and
pointer panels, absent focus and fresh presses. The panel action paths covered
empty and occupied slots. Independent review inspected actual decompilation
and repeated the mechanical checks.

The combined variant preserves the startup-save correction and all other changes
in its predecessor. Its three emitted method bodies match the earlier normal
discard variant exactly. Whole-file reversal recovers the startup-save input,
and the output matches the privately composed movie used on the Brick. The
existing bytecode checks therefore cover these unchanged discard bodies; this
preparation change does not establish a new hardware result.

These results do not establish playable behavior or save safety on the Brick.
The remaining device gate includes both stash panels, cancellation without a
save change, a confirmed discard using a disposable profile, surviving-item
focus, save/reload, normal paging, and physical-button and rendered review.
