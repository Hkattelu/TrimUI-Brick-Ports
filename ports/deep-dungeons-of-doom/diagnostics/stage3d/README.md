# Original Stage3D startup probe

This small original ActionScript movie isolates Stage3D startup from DDD. Its
Sprite document class waits until a stage is available, listens for
`CONTEXT3D_CREATE` and `ErrorEvent.ERROR`, then requests `auto` rendering with the
`baseline` profile. The context callback configures a 550x400 back buffer with no
antialiasing or depth/stencil buffer, clears it green and presents immediately.
`ENTER_FRAME` repeats the same clear/present to keep the visible result stable.

There are no shaders, textures, game assets, network operations, native extensions
or entitlement calls. It does not establish complete Stage3D or game compatibility.
The movie has no internal exit: run it only through an owned, bounded diagnostic
runner. The Brick diagnostic helpers explicitly allow this fixture's pinned hash
as well as the original cyan marker. The default remains the cyan marker.

## Build outside the source checkout

The generator embeds an original empty SWF header and compiles only
`Stage3DProbe.as`; it does not read an existing game or movie. Required external
tools are JDK 17+ (tested with OpenJDK 22.0.2+9-70), JPEXS FFDec 26.3.0 including
its `lib` dependencies, and the `playerglobal32_0.swc` API definitions. These tools
and API definitions are not redistributed here. The generated movie contains the
original program and references to runtime API names, not the playerglobal library.

Example PowerShell commands, run from this source directory:

```powershell
$source = (Get-Location).Path
$ffdec = 'D:/tools/ffdec'
$jdk = 'D:/tools/jdk-22.0.2'
$out = 'D:/private-stage3d-probe'
New-Item -ItemType Directory -Path $out | Out-Null
& "$jdk/bin/javac.exe" -cp "$ffdec/lib/*" -d $out "$source/BuildStage3DProbe.java"
if ($LASTEXITCODE) { throw 'Compiler failed' }
& "$jdk/bin/java.exe" -Djava.awt.headless=true -cp "$out;$ffdec/lib/*" `
  BuildStage3DProbe $source "$out/stage3d-startup-present.swf" `
  "$ffdec/flashlib/playerglobal32_0.swc"
if ($LASTEXITCODE) { throw 'Movie generation failed' }
```

The generator rejects a movie output inside the source checkout/package and uses
create-new semantics. It prints the output size and SHA256. Keep `.class` files,
generated SWFs and diagnostic logs outside this repository. On Linux, use `:` in
the Java classpath instead of Windows' `;` and adjust executable names and paths.

The checked artifact is **2,249 bytes**, SHA256
`4a12a6b904b3fafb28ea38697211c010d71d321e88452bac085c83a6ea0d0bb7`.
An independent build from another source directory produced the same hash.
`provenance.json` records the tool inputs and source hashes from that check.

## Brick entry point

First prepare the private runtime using [the Brick diagnostic instructions](../brick/README.md).
Copy this generated movie and `Stage3DProbe.pak/` alongside the existing
`RuntimeProbe.pak/`, then update `graphics-probe.sh` and
`run-ruffle-graphics-child.sh` from the current source. The new pak calculates its
runtime root from its own installed location and exports `DDD_TEST_SWF` before
calling the existing Ports runner. Only the two exact original fixture names and
hashes are accepted; the checksum checks remain active.

With the menu awake and exclusive display ownership, request the Stage3D pak:

```sh
printf '%s\n' /mnt/SDCARD/.ports/ddd-runtime-test-20261024/Stage3DProbe.pak > /tmp/nextui_open
```

The expected test lasts about ten seconds and returns to the ordinary menu.
`probe.txt` and `result.txt` identify `synthetic-stage3d-startup` and the movie hash.
The original `RuntimeProbe.pak` remains the entry point for the cyan test. Verify
mount release and menu restoration using the Brick diagnostic instructions.

## Read the evidence

The trace markers separate the stages:

| Marker | Meaning |
| --- | --- |
| `STAGE3D_DOCUMENT_CREATED` | The document constructor ran. |
| `STAGE3D_STAGE_READY` | The document has a stage. |
| `STAGE3D_REQUEST auto baseline` | Listeners are registered and a request is about to be made. |
| `STAGE3D_REQUEST_RETURNED` | The request call returned without a caught exception. |
| `STAGE3D_CONTEXT_CREATED` | The context creation callback was dispatched. |
| `STAGE3D_CONFIGURED 550x400 aa=0 depthStencil=false` | Back-buffer configuration returned. |
| `STAGE3D_FIRST_PRESENT green` | The first clear and present calls returned. |

Request return and the asynchronous callback need not have the same ordering in
every runtime. `STAGE3D_REQUEST_ERROR`, `STAGE3D_CONTEXT_ERROR`,
`STAGE3D_CONFIGURE_ERROR` and `STAGE3D_PRESENT_ERROR` include the reported error ID
and message. A present exception stops repeated frame rendering.

The expected picture is a plain green area. A first-present log establishes that
the calls returned; it does not prove the pixels reached the screen. Inspect the
actual visible output, capture only the owned test window/device, and verify that
the bounded runner restores the menu and releases its resources afterwards. A
headless run may exercise a different renderer path, so record it separately.

The seed sets the AS3 FileAttributes flag and leaves UseDirectBlit and UseGPU
unset. The purchased DDD movie has the same values for those three flags; its
UseNetwork flag differs. Source inspection found no UseDirectBlit or AIR-mode
gate in the tested runtimes' context
request/allocation paths: [Lightspark 0.10.0 Stage3D](https://github.com/lightspark/lightspark/blob/0.10.0/src/scripting/flash/display/Stage3D.cpp)
and [Ruffle nightly 2026-10-24 context allocation](https://github.com/ruffle-rs/ruffle/blob/nightly-2026-10-24/core/src/avm2/object/stage3d_object.rs).
Lightspark may still be run with `--air` to match the DDD comparison; record that
choice. In this Ruffle revision an allocation failure logs
`Failed to create Context3d` without dispatching the pending error event. Inspect
the native runtime log if the request returns but no context callback arrives.

The completed checks here are compilation, matching output across source paths,
decompilation and ABC inspection. They confirmed the document class, event
listeners and `requestContext3D`, `configureBackBuffer`, `clear` and `present`
calls.

## Verified desktop result

On October 24, 2026, a bounded Windows64 Lightspark 0.10.0-git run with the
borrowed-slot fallback and `--air --exit-on-error` displayed the plain green frame.
The coordinating agent inspected the rendered output. The log contained all
context-created, configured and first-present markers; reported frame rates
settled at 59–60 FPS. The runner ended only its owned process at the time limit.
The recorded process exit code was `-1`, reflecting that controlled termination.

The exact `libspark.dll` SHA256 was
`314019cab3a42b265708f23404dc39f594bbc32359d8ddb318eae33e69992fcf`.
This was a rendered OpenGL 4.6 run. Its startup log also contained queued-frame
warnings, so it is not described as an error-free runtime test. The private
evidence run is identified as `20261024-212506-930`; logs and captures are not
distributed in the source package.

This result verifies context creation, buffer configuration and visible clear /
present for this original fixture on that desktop runtime. It does not exercise
shader programs, vertex/index buffers, texture sampling, Starling, DDD, controller
input or audio. Brick results must be recorded separately against the device
runtime and the same fixture hash.

## Brick result: API progression, black visible output

The October 24, 2026 Brick run used the same fixture with the pinned ARM64 Ruffle
nightly and isolated libraries from the Brick diagnostic. Ruffle selected
`gl` on `PowerVR Rogue GE8300`. Its log contained every startup marker, including
`STAGE3D_CONTEXT_CREATED`, `STAGE3D_CONFIGURED` and `STAGE3D_FIRST_PRESENT`.
The private evidence is `device-test/stage3d-graphics/ruffle.log` and
`device-test/stage3d-weston/result.txt`; no device logs are distributed here.

The initial screenshot was too early and showed the menu. A later run,
`graphics-20261024-224514-16191`, reached `STAGE3D_FIRST_PRESENT green` at
02:45:17.922 UTC on October 25. A capture taken after that explicit readiness
marker, at 22:45:20 local time on October 24, showed a **black screen**. Both the
coordinating agent and the source agent inspected that image. Its private evidence
is `device-test/stage3d-confirmed.jpg`, SHA256
`ab489a021e2f123ea46de327c6f661ae49c9d976338d9da29e4e3dfc0f5a09c2`.
This is a confirmed visible failure of the clear-only fixture, rather than a
pending capture.

The owned timer ended Ruffle with exit code `143`; the later cleanup record again
reported `westonMountReleased=yes`. The earlier run's menu return was inspected;
this later run did not get a separate menu capture. API progression and mount
cleanup passed; visible green output did not.
Shader programs, textures, DDD, controls and audio remain outside this diagnostic's
scope.

The pinned Ruffle source provides a fixture-specific explanation to test on the
desktop. Its WGPU backend stores a pending color for `clear()`, applies it when
`drawTriangles()` creates a render pass, and resets that pending color in
`present()` without creating a pass. This fixture never calls `drawTriangles()`.
Thus the code predicts that its green clear will be discarded on that revision;
the black result alone does not establish a Brick GPU failure. See
[the pinned backend](https://github.com/ruffle-rs/ruffle/blob/nightly-2026-10-24/render/wgpu/src/context3d/mod.rs#L511).
The stage composition path renders visible Stage3D contexts below the display
list without a UseDirectBlit or UseGPU check, and the backend's `should_render()`
gate only requires a configured back buffer. See
[stage composition](https://github.com/ruffle-rs/ruffle/blob/nightly-2026-10-24/core/src/display_object/stage.rs#L623).
These are source findings, not a completed desktop Ruffle comparison. Keep this
fixture unchanged so that comparison uses the same hash.
