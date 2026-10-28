# Lightspark compatibility experiments

These source files prepare private diagnostic copies. They contain no purchased
game, Steam binary or modified runtime binary. Generated game SWFs must remain
private. The scripts preserve the original inputs and reject unrecognized hashes
and existing outputs.

The latest private PC run reached the actual DDD title screen using the existing
`-fs` startup-fullscreen option together with the borrowed-slot runtime fallback,
window-hint adaptation and audio enum. Gameplay, input and audio remain untested;
DDD has not yet run on the Brick. The selected Brick direction is a lightweight
offline compatibility layer for a locally supplied purchased copy, with no Steam
client on the device. The [offline preparer](../offline/README.md) now supplies a
private startup adaptation for Ruffle. A bounded desktop run reached Starling
initialization with Steam unavailable; offline visual and device validation are
pending. These native Steam PC experiments remain diagnostic evidence.

## Interpreter failure

Lightspark 0.10.0 win64 crashed at `libspark.dll+0x21f6a7` after the game's genuine
Steam subscription check returned true. The same fault occurred with rendering
enabled. Its opcode table identifies
`abc_callpropvoidBorrowedSlot_constant_local` (opcode `0x3d6`). A bounded debugger
read identified method 550, borrowed slot 3, and a variable pointer containing the
Windows heap guard pattern. The method calls a static event dispatcher whose name
also belongs to an overridden instance method.

`borrowed-slot-fallback.patch` disables that borrowed-slot optimization and keeps
ordinary property dispatch. `Prepare-BorrowedSlotFallback.ps1` makes the equivalent
six-byte change in one exact unpacked runtime DLL. The private headless test then
completed Starling initialization. `static-receiver-guard.patch` is a separate, narrower
proposed source fix; it has not been built or validated by that binary test.
These two interpreter patches are alternatives; do not apply both.

The official packed DLL SHA256 is
`88fa4fe0761a332d062901be2f3870e01fecd35f7cbe85901e327df8151620fc`.
UPX 5.2.1 decompression to a separate file produces
`7e954372ae39143cb1b87f16a66a9343f99374bae13316d3413974083bd1c832`.
The script verifies that full hash and the surrounding machine instructions.
It changes the conditional branch at RVA `0x177f9e` to six NOPs. The preceding
instruction retains `UINT32_MAX`; the fall-through at RVA `0x177fa4` clears the
cached function and uses the existing fallback. The resulting DLL hash is
`314019cab3a42b265708f23404dc39f594bbc32359d8ddb318eae33e69992fcf`.

## Desktop audio category

`AudioPlaybackMode.as` implements the three public AIR constants. The
[AIR documentation](https://airsdk.dev/reference/actionscript/3.0/flash/media/SoundMixer.html#audioPlaybackMode)
states that these modes have no functional difference on desktop or TV. An
original-source probe confirmed that Lightspark can store and read the category
on its existing `SoundMixer` class. The existing mixer and playback methods remain
in use.

`audio-playback-mode-class.patch` provides the same three constants as a native
Lightspark class for a source build. It adds class registration and leaves the
existing mixer implementation unchanged. This patch has passed an apply check;
the native build and runtime test are separate pending checks.

Use PowerShell 7, an installed JDK, FFDec 26.3.0, and the caller's existing
`playerglobal32_0.swc` to build the enum library. Those dependencies are not
included. Set the variables to local paths, then run from this directory:

```powershell
./New-EmptyProbe.ps1 -OutputFile $emptySwf
& $java -Xmx512m -cp $ffdecJar ./BuildAudioProbe.java `
    $emptySwf $PWD $enumLibrary $playerglobal --library-only
./Prepare-AudioModeProbe.ps1 -GameFile $windowHintProbe `
    -EnumLibraryFile $enumLibrary -OutputFile $privateOutput
```

The enum library's expected SHA256 is
`c6ea5e877c562fb5b2ea89229484c93455902b9f55d4da8845efeaa9326633d2`.
Builds from two different source directories produced that same hash. Omitting
`--library-only` builds `AudioRepro`, which verifies category assignment and
prints `AUDIO_DONE`. Neither generated fixture is included in the source package.

The private game preparer inserts only the enum's 387-byte ABC tag before the
game's ABC. Removing it and restoring the header reproduces the entire input
file exactly. Its sidecar records this check and the output hash. This removed
the missing `AudioPlaybackMode` exception in the purchased game test.

## Scissor render queue

After the enum addition, the headless run reached a new native fault at
`libspark.dll+0x397c36`. `Context3D.setScissorRectangle` reads the last queued
render action without first checking that the queue has an entry.
`scissor-empty-queue-guard.patch` adds the missing source check.
Earlier rendered runs survived 25- and 60-second limits without this fault, but
did not print the Starling initialization marker. Inspection of the actual window at
startup and roughly 30 seconds showed a black screen. The later startup-fullscreen
run below reached the title without applying the scissor fallback. Keep this
scissor experiment separate from the rendered test's borrowed-slot runtime variant.

`Prepare-ScissorQueueFallback.ps1` is a separate, conservative binary experiment:
it disables consecutive-scissor coalescing and always queues the same rectangle.
It removes the unchecked comparison and branch at RVA `0x397c36`, then enters
the existing add-action path at `0x397c43`. This preserves scissoring; it does not
drop render commands. Its input is the exact borrowed-slot variant and its output
is a new file. Runtime validation of this second fallback is pending.
`scissor-queue-fallback.patch` records its exact source equivalent. It and the
narrow empty-queue guard are alternatives, not cumulative patches.

## Fullscreen startup deadlock

Two bounded snapshots of the black-screen test, eight seconds apart, showed the
same circular wait. The VM thread was inside `SDL_SetWindowFullscreen`, called
by `EngineData::setDisplayState` at `libspark.dll+0x71e392`. The SDL event-loop
thread was waiting for the VM's `IdleEvent` through `WaitableEvent::wait` and
`SystemState::waitMainSignal`. An independent Stage3D fixture reached its context
callback, clear, present and approximately 60 FPS without this fullscreen change.

`fullscreen-main-thread.patch` is a proposed source fix. It queues the window
operation through the existing `runInMainThread` callback, letting the VM finish
its frame while SDL applies the mode and resize on its event-loop thread. The
callback captures only the requested fullscreen boolean; the existing Stage
property remains unchanged. Window size and resize events consequently update
asynchronously. This patch passed source application checks and an independent
review. It also compiled and linked in the private ARM64 build alongside the
borrowed-slot fallback and native audio enum; that build has not run on the device.

The runner's optional `-StartFullscreen` switch adds Lightspark's existing `-fs`
argument and records it in the run report. That initializes fullscreen on the
event-loop thread before game startup. SDL skips a request whose fullscreen flags
already match, so this is a tested workaround for this initial transition.
The independent fullscreen fixture passed with `-fs`: its fullscreen setter
returned, it created a Stage3D context and presented its green frame, which was
also visually inspected. The corresponding DDD run `20261024-223458-925` then
displayed the actual Deep Dungeons of Doom title and click-anywhere prompt. The
coordinating agent inspected the rendered title; stdout contained
`[Starling] Initialization complete.` The owned 60-second limit ended with a
graceful exit code 0.

That run used `libspark.dll` SHA256
`314019cab3a42b265708f23404dc39f594bbc32359d8ddb318eae33e69992fcf`
and the private window-hint/audio-enum SWF SHA256
`ca16437f19fd7451e4090f05861e999d77d269f9f3e78dfbfddde15f2237ff14`.
The original SWF, private SWF and runtime DLL hashes were identical before and
afterward. It used the existing `-fs` argument, not the proposed fullscreen source
patch or scissor fallback. No title-screen click or gameplay was attempted, and
the dummy audio driver means sound was not tested.

This option does not fix subsequent mode changes and makes no change to game
files, runtime binaries or Steam checks. Use it with `-Render` for a separately coordinated
graphical test.

## Source licenses and validation limits

The `.patch` files modify Lightspark source and are covered by
**LGPL-3.0-or-later**, retaining its upstream authorship. Their base is the official
[Lightspark 0.10.0 source](https://github.com/lightspark/lightspark/tree/0.10.0).
See upstream [COPYING.LESSER](https://github.com/lightspark/lightspark/blob/0.10.0/COPYING.LESSER)
and [COPYING](https://github.com/lightspark/lightspark/blob/0.10.0/COPYING).
The standalone helper scripts, Java compiler driver and ActionScript enum/probe
are original project source.

The Lightspark PC title test kept the original Steam call and result. The inspected
title establishes startup rendering for that exact configuration; it does not
establish gameplay, working sound output or an ARM64 game port. The intended
offline startup adaptation has a separate desktop API progression check, with
device/gameplay testing pending. A small
independent static and instance dispatch control passed in both runtimes; it did not reproduce the
game's original crash and is not a regression test for that crash.
