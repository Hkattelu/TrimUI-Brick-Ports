# DDD launcher source

These original launcher sources adapt the existing private Weston/Ruffle test
setup to the NX Redux Ports menu and the separate PortMaster adapter. They contain
no game movie or runtime binary.
The installer supplies the purchased-copy movie, reviewed ARM64 runtime and full
portable dependency tree, then creates the integrity manifest locally.

Install `Deep Dungeons of Doom.sh` in `/mnt/SDCARD/Roms/Ports (PORTS)/`. The existing
Ports runner supplies its normal setup. This legacy entry calls `launch.sh` directly at
`/mnt/SDCARD/.ports/deep-dungeons-of-doom`; it does not start another Ports runner.
For the portable package layout use the entry in `../portmaster/`. Both supply
`DDD_WESTON_RUNTIME`; the core derives its root from its own script location.
The PortMaster entry preserves NX's conventional `GAMEDIR` discovery. Core script
syntax also survives NX's library-path normalization without invalidating hashes.

The private install root contains:

```text
launch.sh
run-game.sh
launcher-common.sh
ddd-log-drain                  compiled from ddd-log-drain.c
ddd-exit-watch                 compiled from diagnostics/brick/ddd-exit-watch.c
ruffle
ddd.swf                       private, locally prepared purchased copy
libddd_alsa_poll_recovery.so
portable/                     complete reviewed runtime dependency tree
manifest.sha256               locally generated data-only digest list
profile/                      persistent saves; never overwritten by the launcher
logs/run-<timestamp>-<pid>/    bounded service logs and small result records
```

The manifest uses `sha256sum` text format: a lowercase 64-character SHA256,
two spaces, and the relative file path. Include each of the eight fixed files
above before `portable/`, and every file reached within `portable/`, including
file symlink aliases. Exclude the manifest itself, profile, logs, source files and
menu entry. Paths are restricted to ASCII letters, digits, `_`, `.`, `/`, `+`
and `-`. Traversal, absolute paths, duplicate entries, unknown top-level files,
escaping symlinks, missing dependencies and changed file contents are refused.
The loader must be executable. The manifest checks installation integrity;
the installer is responsible for supplying the reviewed hashes and contents.

The fixed PortMaster Weston squashfs is checked separately against SHA256
`4c929287617b1276b5cbffcd188eea77aa979a2a84524fd222d03ed3d408c82b`.
The launcher mounts it read-only and retains the tested headless/noop/kiosk plus
crusty X11 rendering route. Its original process handles and start times govern
cleanup; it never kills by process name. Shared runtime paths must be absent
before launch and are removed only if their original device/inode identity still
matches. Existing mounts, sockets or other display sessions cause refusal.

Ordinary launches have no session deadline. An explicit `--test-seconds N`
argument, from 1 through 600, bounds the game phase for validation; compositor
startup also has its own readiness deadlines. Each service log keeps at most
4 MiB. The original C log consumer continues draining after that cap or a write
failure, so a full log does not kill the game. Current logs are retained per run;
the launcher does not delete old logs or saves.

Ruffle uses `profile/` with the stable movie identity
`file:///ddd-offline/ddd-offline.swf`, even though the local file is named
`ddd.swf`. The installer may copy validated complete save banks into a new
profile; the launcher only creates a missing profile and never migrates data.
Each run writes `enable_openh264 = false` in its private Ruffle preferences before
startup. This disables the optional codec download, which is independent of the
movie's network restrictions; Ruffle retains its software video backend.

The explicit gamepad mapping is D-pad to arrows, South to Return, East to Escape,
West to Space, North to C, and the two trigger buttons to Left/Right. Start and
Select are absent. In the pinned Ruffle source, a nonempty custom map replaces
the default map, and unmapped gamepad events are ignored. The separate quit
watcher observes the uniquely named `TRIMUI Player1` evdev device and requires
pressing Start+Select together. If it cannot start or later disappears while the
game is still running, the child stops its own runtime and returns through the
parent cleanup. Physical Nintendo face-button positions still require a Brick
check; the labels here refer to Ruffle's gamepad event names.

Focused local checks (Linux with a C compiler and Python 3):

```sh
python3 tests/test-log-drain.py
python3 tests/test-launcher.py
python3 tests/test-game-exit.py
```

These compile and exercise the log consumer, validate manifest refusal cases,
and use disposable processes and paths to test ownership and exit-status races.
The shutdown check reproduces the old false failure and verifies that genuine
monitor failures still stop the owned runtime. They do not mount the
display runtime, touch controller devices or launch DDD. Brick validation still
must cover ordinary menu startup, rendered play, button behavior, quit/return,
save reload and cleanup. Audio audibility remains a separate hardware check.
