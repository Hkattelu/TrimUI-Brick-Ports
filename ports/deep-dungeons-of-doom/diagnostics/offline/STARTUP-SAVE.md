# Preserve the checkpoint during startup

The previous candidate saved a newly created dungeon before restoring its
loaded state. That replaced the disk checkpoint with initial room values and
zero elapsed time. A subsequent ordinary floor move could recover the loaded
progress, but quitting before that move could leave the initial snapshot as the
next launch's save.

This candidate skips only that premature `setDungeon`/`save` pair for the exact
dungeon being restored. A temporary private static identity marker spans the
existing synchronous scene-add call. Both normal and catchable-error exits
restore the previous marker. The original private restore then runs in its
original position. Other new-dungeon saves and normal movement saves retain
their existing paths.

The game's intentional reconstruction of an earlier safe room remains unchanged.
The patch does not save that reconstructed room immediately, because repeatedly
doing so could move the stored checkpoint backward on later launches.

## Prepare a separate private candidate

Use PowerShell 7.2 or later and preserve all existing game files:

```powershell
./Prepare-StartupSaveProbe.ps1 `
  -PrivateGameFile C:/private-tests/ddd-encyclopedia-back-silent.swf `
  -OutputFile C:/private-tests/ddd-startup-save.swf
```

The helper accepts only the silent-logo/Up-wrap/Encyclopedia Back input with
SHA256 `a308ea6466305b6e9a553387f67c8f8b317edf0d0fa57f09bb47a1e0b537f3f7`.
Its output is 28,620,745 bytes, SHA256
`c06c703c96cb1a3af5f006f2cb68a11f0d2d31118e5bb4cbd71d6b2951409f8e`.
This helper does not prepare the normal-logo variant, install files, run the
game, or distribute game content. It refuses an existing output/report,
unrecognized input, reparse paths and outputs inside the source package.

The [discard preparer](STASH-DISCARD.md) accepts this output and adds the existing
button route to stash discard confirmation. Its combined result retains this
startup correction; the discard interaction still needs hardware validation.

Only methods 260 and 320, one appended private static slot and its appended
string/QName metadata change. Existing instance layouts and pool indices stay
intact. The output adds 67 bytes. Whole-file reversal recovers the exact input.
An independent reconstruction reproduced every output byte; an interpreter of
the actual emitted instructions passed 53 focused marker/dispatch/error cases.
Those external-call stubs do not emulate the complete game or AVM verifier.

## Brick evidence — October 25, 2026

Two bounded NX Ports launches used the exact output above with the b381
pipeline-cache runtime and a separate copy of the existing save. The second
launch's input was byte-identical to the first launch's resulting profile.
Root inspected both restored dungeon views before sending any gameplay input.

| Captured state | Saved elapsed time | Saved current/max/added levels |
| --- | ---: | --- |
| Seed checkpoint | 92.45 seconds | 1 / 1 / 1 |
| First startup, no movement | 92.45 seconds | 1 / 1 / 1 |
| Second startup, no movement | 92.45 seconds | 1 / 1 / 1 |
| One ordinary Down movement | 169.12 seconds | 1 / 1 / 1 |

Both startup comparisons changed only achievement accumulators and timestamps;
save banks rotated normally with matching selectors and no fallback. All 13
player scalar fields, the object structure and 32 reference aliases remained
unchanged. The normal movement updated elapsed time and retained player state.
The earlier safe-room reconstruction explains why moving again reaches the same
saved level; this is checkpoint preservation, not proof of exact-room continuation.

After the movement snapshot, a fresh R-shoulder tap advanced the attack tutorial
to its cooldown tutorial. Root waited for the visible Continue prompt and used
Return to return to the practice dummy. The immediate attack capture preceded
the visible response; the later capture established the tutorial transition.
This does not establish an exact damage amount, defensive timing, input feel or
combat mastery.

Both owned stops returned 143, released their Weston mounts/display paths and
returned to the inspected NX Tools menu. Automatic restoration verified all 461
ordinary installation entries. The ordinary save remained unchanged throughout;
the private test profile was retained separately. These runs restored the earlier
ordinary installed movie and runtime. No audio check was attempted.

Remaining validation includes nonempty inventory, earned-item persistence,
later progression, fresh/revenge gameplay paths and physical controls. The
source-level marker cases cover fresh/revenge dispatch conditions; they are not
hardware playthroughs. The original game data, modified SWFs, snapshots and raw
runtime logs remain private and are excluded from the source archive.
