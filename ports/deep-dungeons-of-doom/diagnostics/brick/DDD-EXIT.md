# Owned exit watcher

`ddd-exit-watch.c` reads the named `TRIMUI Player1` evdev device without an
exclusive grab. Pressing Select (314) and Start (315) together requests `SIGTERM`
for one verified runtime process. Holding either and tapping the other works;
there is no hold timer. Neither button is mapped to a game action in the private
player launcher. Single-button presses do not quit. Home is not a quit shortcut.

The caller supplies the runtime PID, its `/proc/PID/stat` start-time field, the
exact absolute runtime path, and the exact absolute movie path. The watcher
captures the complete NUL-separated command line, requires both paths as whole
arguments with the movie last, and rechecks the PID start time and complete
command line before signaling. It never searches by process name, uses global
`pkill`, grabs the controller, or escalates to `SIGKILL`.

```sh
ddd-exit-watch /dev/input/event3 "$ruffle_pid" "$ruffle_start_ticks" \
    "$test_root/ruffle" "$test_root/ddd-offline.swf" &
exit_watch_pid=$!
```

Discover the evdev path by its device name; `event3` is the currently observed
Brick mapping, not a portable guarantee. Capture the target start time from the
actual launched process. The helper supports the existing glibc-loader command
line because it matches whole runtime/movie arguments rather than assuming the
runtime is argument zero.

The parent must retain ownership of the watcher PID, stop it with `SIGTERM`, and
wait for it during cleanup. The watcher also exits when its parent changes or
the target identity no longer matches. If either button is already held at
startup, both must first be released. An input overrun disarms the watcher until
the next sync report has discarded stale events and fresh button releases occur.
Keep the watcher tied to the parent's owned runtime child throughout cleanup.
On the Brick's Linux 4.9 kernel, the identity check and `kill` are not atomic;
the repeated checks narrow PID reuse races but cannot provide a pidfd guarantee.

Exit codes: 0 means an exit request was sent or the watcher was stopped; 2 means
invalid arguments; 3 means an input error; 4 means target/parent identity
changed. A requested termination does not establish that the game saved its
latest progress. Validate normal saving and relaunch separately in the isolated
profile before offering this as the final player launcher.

From this `diagnostics/brick` source folder, compile with a Linux C compiler.
Keep all binaries in a separate temporary directory:

```sh
test_dir=$(mktemp -d /tmp/ddd-exit-watch-test.XXXXXX)
cc -std=c11 -O2 -Wall -Wextra -Werror ddd-exit-watch.c -o "$test_dir/ddd-exit-watch"
cc -std=c11 -O2 -Wall -Wextra -Werror tests/test-exit-watch.c -o "$test_dir/test-exit-watch"
"$test_dir/test-exit-watch"
```

Use the absolute test executable path as shown: its own disposable child is the
verified runtime fixture, and runtime paths must be absolute. The test supplies
synthetic events through a pipe. It checks short chords in either order, single
presses, repeats, split records, identity and parent mismatches, stopping the
watcher, startup-held buttons, and stale events after `SYN_DROPPED`. It never
opens a controller or launches a game. The deliberate `/dev/null` device check
prints an expected device-rejection message. Do not compile these assertion
tests with `-DNDEBUG`.

Use the private ARM64 compiler and sysroot for the Brick build. The current
private build requires GLIBC 2.34; launch it with the isolated runtime's loader
and library path, because the Brick firmware has GLIBC 2.33. No binary, game
assets, or save data belong in this source package.

## Brick validation

On October 26 the user could not quit the audio-enabled play session. The input
trace recorded Start held while Select was tapped for about 160–216 ms, below
the old 800 ms simultaneous-hold threshold. The watcher was alive, with no exit
request logged. An identity-checked SIGTERM recovered the session, returned 143,
released Weston and restored all 461 manifest entries; the captured NX Tools
menu was inspected. The latest saved files were backed up without rollback.

The revised source removes that hold requirement. Its disposable-process test
passed on both the host and the Brick, including press/release in one read,
single-button rejection, startup release and overrun guards. The production
ARM64 binary loaded with the isolated loader.

The integrated silent run `run-20261026-121510-5034` then used the ordinary
NX/PortMaster launcher, runtime `3d8a8e5c...`, movie `7406fc2c...` and a separate
profile copy. A guarded synthetic Start press followed by a 160 ms Select tap
produced the exit-request log, child/parent 143 and `westonMountReleased=yes`.
NX returned, all 461 baseline entries were restored, and the canonical human
profile hashes were unchanged. The new production helper has SHA-256
`3f519514adf9abc55bfdfedd53be5a942796a0b3efc3262b7be2eb404473cb4b`.
This establishes the integrated short-chord path; physical use remains a human
check. No game controls, mixer settings or save data were changed by the fix.

The following evidence describes the previous hold-based version:

Private run `graphics-20261024-235918-27201` exercised the watcher on the actual
`TRIMUI Player1` evdev device using guarded synthetic Select+Start events. The
watcher logged `DDD exit requested for the verified runtime process.` The game
exited with status 143, the timer marker was absent, and the parent recorded
`westonMountReleased=yes`. The test released both resource reservations.

This verifies the device event path, owned termination and display cleanup for
the private harness. It does not establish physical button feel, saving on quit,
or integration with a finished player launcher. The runtime was the pinned
ARM64 Ruffle build and the movie was the private keyboard-menu variant
`c92867d7cdf6e86652562889d46641b4ff228feae042ce4b6cb8ca57161d4ce7`.
