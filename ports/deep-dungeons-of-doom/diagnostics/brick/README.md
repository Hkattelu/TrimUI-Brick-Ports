# Synthetic Brick graphics diagnostic

This source package reproduces a small graphics experiment on the **original
TrimUI Brick**, using NX Redux's Ports launcher, an already installed PortMaster
Weston runtime, and a private ARM64 Ruffle userspace. It contains no DDD data,
downloaded binaries, Steam libraries, or device logs. It is not a DDD launcher.

On October 24, 2026, the tested setup displayed an original cyan SWF on the Brick.
Ruffle initialized the PowerVR GE8300 OpenGL adapter; the timed run returned to the
NX Redux menu and released its private Weston mount. This establishes basic
rendered SWF output. A separate original Stage3D probe subsequently logged context
creation, buffer configuration and first present on the Brick, then released its
mount and returned to the menu. A capture taken after its first-present marker
showed a black screen, so visible Stage3D output has not passed. The pinned
Ruffle source appears to discard this fixture's clear-only frame unless a draw
call creates a render pass; that is a runtime lead, not proof of a Brick GPU
failure. See the [Stage3D evidence](../stage3d/README.md).
DDD startup/gameplay, shader and texture use, game controls, audio and saves remain
unverified. A successful marker does not establish those capabilities. The source
package adds PID identity checks to the tested cleanup
and an exact Ruffle hash guard. Focused checks of those actual cleanup functions
passed: owned processes stopped while unrelated and mismatched identities were
preserved. The packaged dependency preparation was also rerun successfully from
its pinned downloads, producing 62 AArch64 ELF objects with no missing declared
dependencies. Those source checks do not replace the separate rendered evidence.

## Exact external dependencies

- Original Brick: AArch64 Linux 4.9.191, firmware glibc 2.33, 1 GB RAM, firmware
  PowerVR graphics libraries. The tested display size is 1024x768.
- NX Redux with `/mnt/SDCARD/Emus/PORTS.pak/launch.sh`, supporting its native
  `/tmp/nextui_open` menu handoff. Its normal runner handles menu/power/CPU restore.
- Existing `/mnt/SDCARD/Emus/shared/PortMaster/libs/weston_pkg_0.2.squashfs`,
  **44,654,592 bytes**, SHA256
  `4c929287617b1276b5cbffcd188eea77aa979a2a84524fd222d03ed3d408c82b`.
  Its wrapper identifies itself as 0.2.8 Preview 1. The probe selects the inspected
  headless/noop/kiosk/XWayland/crusty_x11egl configuration and refuses another hash.
  It does not execute that wrapper's broader cleanup or global setup branches.
  Obtain PortMaster through its normal installation; this package does not fetch
  or replace it. See the [PortMaster source](https://github.com/PortsMaster/PortMaster).
- [Official Ruffle nightly 2026-10-24](https://github.com/ruffle-rs/ruffle/releases/tag/nightly-2026-10-24),
  asset `ruffle-nightly-2026_10_24-linux-aarch64.tar.gz`, 13,153,506 bytes, SHA256
  `49b49213f32dabcdabbc2f9cd46cdf9653125069f429f54ec7b09fa2f9848720`.
  The extracted `ruffle` is 33,927,320 bytes, SHA256
  `6814582ba9bbf9a3cdd062b3e7cf1a37043e75d6c752e665aee4edf7c5dec121`.
  Keep the release's license and notices with private copies. This executable
  needs glibc 2.39; use the isolated loader below, never replace firmware libc.
- The 20 exact Ubuntu Noble ARM64/all packages in `packages.lock.json`, totalling
  7,093,412 download bytes. They include glibc 2.39-0ubuntu8.9, OpenSSL
  3.0.13-0ubuntu3.16, ALSA, FreeType and client-side display dependencies. Firmware
  EGL/GL/DRM drivers remain firmware-owned; no Mesa driver is bundled.
- Build host: PowerShell 7, an existing 7-Zip executable, and Linux/WSL Python 3.9+
  with `libzstd.so.1` plus `readelf`. These scripts install no tools or packages.
  Device commands used are the firmware's `sh`, `awk`, `cut`, `sha256sum`, `pidof`,
  `mount`/`umount`, `readlink`, `mkfifo`, `date`, `sleep`, and basic file utilities.

The package hashes were obtained from the official Ubuntu `noble`,
`noble-security` and `noble-updates` ARM64 package indexes. Their compressed index
hashes were checked against the corresponding InRelease contents fetched over
HTTPS. The original preparation did **not** independently verify the InRelease
OpenPGP signature. This source pins the reviewed package URLs and hashes and fails
if a download differs; it does not silently select newer versions. It preserves
package copyright files. See `provenance.json` for the index hashes and origins.

## Prepare a private copy

Use a new directory outside this Git checkout. The examples below are illustrative
paths; use your actual source directory and existing WSL distribution. No step
requires a game installation.

```powershell
# Run from this diagnostic source directory.
./Prepare-Libraries.ps1 -OutputDirectory 'D:/brick-runtime-probe' `
  -SevenZip 'C:/Program Files/7-Zip/7z.exe'
./New-MarkerSwf.ps1 -OutputFile 'D:/brick-runtime-probe/marker-550x400.swf'
Copy-Item ./graphics-probe.sh,./run-ruffle-graphics-child.sh 'D:/brick-runtime-probe'
Copy-Item ./RuntimeProbe.pak 'D:/brick-runtime-probe' -Recurse
```

The preparer accepts only a new directory, downloads the locked packages,
checks size and SHA256, and extracts their data archives with 7-Zip. No package
maintainer script runs. Retain a failed output for diagnosis and use another new
directory after correcting the cause.

Download the exact Ruffle release asset linked above into a separate private
directory. Verify its archive hash before extracting; copy `ruffle` and the
release's notices into the probe directory. Confirm the executable hash too.
Then use Linux/WSL with paths translated for that environment:

```sh
python3 /path/to/this/source/assemble_runtime.py --root /mnt/d/brick-runtime-probe
python3 /path/to/this/source/check_dependencies.py \
  --root /mnt/d/brick-runtime-probe --ruffle /mnt/d/brick-runtime-probe/ruffle
```

Assembly creates `portable/` and `portable-arm64-libraries.tar.gz`. Library aliases
become regular files for FAT/exFAT storage. Copyright files, ALSA data and XKB data
are retained. `portable/files.json` records every extracted file's package and
SHA256. The ELF check examines declared dependencies and architecture without
executing ARM64 code; it cannot establish GPU, dynamic-library or kernel behavior.
An existing `portable/` directory is rejected so stale files cannot enter a bundle.

Copy only `ruffle`, its notices, `portable/`, the generated marker, the two main
shell scripts and `RuntimeProbe.pak/` to this **new private device directory**:

```text
/mnt/SDCARD/.ports/ddd-runtime-test-20261024/
  ruffle
  portable/lib/ld-linux-aarch64.so.1
  portable/...                         (all generated portable contents)
  marker-550x400.swf
  graphics-probe.sh
  run-ruffle-graphics-child.sh
  RuntimeProbe.pak/launch.sh
```

Preserve LF shell line endings. Mark the loader, Ruffle and three shell scripts
executable if the filesystem requires it. Compare transferred files with the
host's hashes and `portable/files.json`; never assume a successful copy verifies
integrity. Keep the downloaded packages and host build outputs off the device.

## Run through the normal menu handoff

Have the Brick awake at the NX Redux menu, with no other port or display session
running. Coordinate ownership before running graphical tests. The script refuses
an existing seatd/Weston/XWayland process or occupied fixed display paths. It leaves
`/tmp/lib` intact. It neither changes Keep awake over USB nor any other setting.
If you manually enable that menu option for a test, restore your previous value
afterwards.

From a device shell, the native menu request is:

```sh
printf '%s\n' /mnt/SDCARD/.ports/ddd-runtime-test-20261024/RuntimeProbe.pak > /tmp/nextui_open
```

The menu invokes the pak, which calls the existing Ports runner. Do not start the
graphics script beside an active menu renderer. The expected visible result is a
cyan screen for about ten seconds, followed by the ordinary menu. Startup has a
ten-second XWayland readiness limit and the parent session has a forty-second
deadline, followed by bounded cleanup. Timer termination can yield a nonzero
process exit code; inspect the results and visible menu instead of treating that
number alone as success or failure.

The private directory receives `latest-weston-run.txt`, `latest-graphics-run.txt`,
and timestamped logs under `runs/`. Check that `result.txt` in the Weston run says
`westonMountReleased=yes`, inspect `ruffle.log`, and confirm the menu is visible.
An unmount failure leaves its private mount for diagnosis instead of forcing a
lazy unmount. No automatic repair of an unrelated or occupied runtime is attempted.

An optional [original Stage3D startup fixture](../stage3d/README.md) is also
accepted by its exact filename and SHA256. Its separate `Stage3DProbe.pak` exports
`DDD_TEST_SWF` to select it; the default remains `marker-550x400.swf`. Every child
run records its fixture identity and hash in `probe.txt` and `result.txt`.
No arbitrary SWF path or game movie is accepted by these helpers.

## Cleanup ownership and scope

`graphics-probe.sh` mounts only the pinned image at `/tmp/ddd-graphics-PID/weston`
and unmounts only that path. It records PID start times for its seatd, Weston,
client and deadline; it records Weston's descendants for cleanup. Signals are sent
only when the current PID start time matches the saved identity. The child uses
the same check for Ruffle and its watcher. Short-lived timer `sleep` children may
finish after a watcher is stopped; they hold no display or mount resources.

The runtime requires fixed `/tmp/fonts`, `/tmp/share`, `/tmp/.X11-unix`,
`/tmp/drmpipe` and `/run/seatd.sock` paths. The probe starts only when those names
are absent and removes only names it acquired. Symlink cleanup checks its target.
These names require exclusive display ownership for the whole test; do not start
another compositor concurrently. It performs no global `pkill`, udev trigger,
`/run` bind mount, firmware update, recursive cleanup or game-data operation.

`LD_PRELOAD` is applied only to the actual Ruffle loader invocation. The verified
crusty shim writes to stdout, so exporting it into checksum commands would corrupt
their captured output. The child runs from the private test directory so it does
not retain the Weston mount as its working directory.

Further DDD work must solve the game's runtime/API and Stage3D requirements,
ownership checks and controller mapping separately. Nothing here substitutes a
Steam entitlement result or grants redistribution rights for game files.
