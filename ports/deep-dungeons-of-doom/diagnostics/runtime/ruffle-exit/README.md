# AIR Exit Game fix

On October 27, Himan reported that DDD's in-game Exit Game action did nothing.
This is separate from the accepted Start+Select quit shortcut. The game's main
menu calls `NativeApplication.nativeApplication.exit(0)`, but the accepted Ruffle
runtime implements that AIR method as a stub. Packaging alone does not fix it.

`native-application-exit.patch` routes the call through `fscommand("quit")`.
Ruffle's desktop handler posts `ExitRequested`, closes its event loop and drops
the player. The player's normal destructor flushes shared objects, and the
launcher can then finish its existing process-owned cleanup. The renderer,
audio mixer, input map and private game movie are unchanged by this patch.

The source candidate is `8a8c9ef6b5b8d3aa4fd0594dbe3f347cd3ba1341`, based on
accepted checkpoint `d3978ccb84e10dabbbd8710caf74f0946eb56671`. It changes one
ActionScript source file. The original public runtime license is retained in
`../ruffle-amf/RUFFLE-LICENSE.md`.

The existing host quit command does not carry a nonzero process exit status.
This patch also does not implement AIR native-window close/cancel behavior.
DDD uses the zero-status path. Calling `exit()` must not itself dispatch an
`exiting` event, according to the
[AIR reference](https://airsdk.dev/reference/actionscript/3.0/flash/desktop/NativeApplication.html).
The original fixture checks that no such event appears.

## Focused regression

`NativeExitProbe.as` is an original soundless movie with no game content. It
requests AIR exit on its second frame. The expected output ends after the
request returns. A later frame emits a failure marker, which catches the old
stub's continued execution. The test harness uses its normal quit-command
receiver to finish the test. No renderer or audio device is required.

Compile `BuildNativeExitProbe.java` with JDK 17 or later and FFDec's `ffdec.jar`
plus `lib/*` on the classpath. Run it with three arguments: this source folder,
a new output SWF outside the source checkout, and `playerglobal32_0.swc`.
The generated 1,249-byte fixture has SHA256
`2292cfd18ce0abb5c602c772dd79c898f48bd2298c9bc5323bee19edc965c1c8`.
The fixture uses `getDefinitionByName` so it can be compiled without proprietary
AIR SDK libraries.

For the Ruffle harness, place that movie as `test.swf` beside this `test.toml`
and `output.txt` in a private `tests/swfs/avm2/native_application_exit/` directory.
From the directory containing `tests/swfs`, run the compiled regression-test
executable with `avm2/native_application_exit --exact`. Build that executable
using `cargo test --locked -p tests --test tests --no-run`, without `imgtests`.

The cached October 25 headless baseline failed with two later-frame markers.
Its AIR exit source matches the accepted stub. The newly built source candidate
passed with only the expected three trace lines. This establishes the quit
request in the headless runtime. It does not establish native window shutdown,
device cleanup, hardware save reload or a successful PortMaster installation.

The ARM64 candidate built with the accepted `dist` profile, fat LTO and one
codegen unit. Its stripped binary is 27,873,968 bytes with SHA256
`dac0115d86d31618c1d82270771f5ecbb3d849f973efddebfbc4b286eef5fda5`.
An ELF audit checked 16 objects against the existing portable libraries, with
no missing dependencies or symbol versions and no additional libraries needed.
That audit does not execute ARM code or test libraries loaded at runtime.

The October 27 native check reached the main menu using a recovered private save
copy. It exposed a separate graphics-wrapper teardown panic. With the original
[Crusty compatibility proxy](../../brick/EGL-SHUTDOWN.md), the in-game Exit action
returned to NX in about two seconds, both processes reported status 0, and the
Weston mount was released. The menu, selected action and returned NX screen were
inspected. The live save remained byte-identical to its backup.

The new AMF writer and repeated save/reload checks remain pending; its ARM build
is blocked by host disk space. The silent candidate also logged ALSA errors.
The installed playtest and packaged runtime remain at their previous identities
until those checks pass. Preserve the player's latest save before changing them.
