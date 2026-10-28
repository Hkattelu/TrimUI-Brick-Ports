#!/bin/sh
# Invoke from graphics-probe.sh after it has acquired the display paths.
# This helper owns only its Ruffle child and deadline watcher. It does not
# start/stop Weston, alter the menu, mount files, or change system settings.
set -eu

test_root=${DDD_RUNTIME_ROOT:-/mnt/SDCARD/.ports/ddd-runtime-test-20261024}
swf=${DDD_TEST_SWF:-$test_root/marker-550x400.swf}
seconds=${DDD_TEST_SECONDS:-15}
case "$seconds" in 5|10|15|20|30) ;; *) echo 'Unsupported probe duration'; exit 2 ;; esac
case "$test_root" in /mnt/SDCARD/.ports/ddd-runtime-test-*) ;; *) echo 'Unexpected test root'; exit 2 ;; esac
case "$swf" in
    "$test_root/marker-550x400.swf")
        probe=synthetic-2d-marker
        expected_swf=e633eebe366bee81572daf62e98b4ece1f3edb011f4b5559b527dbe51dd134b4 ;;
    "$test_root/stage3d-startup-present.swf")
        probe=synthetic-stage3d-startup
        expected_swf=4a12a6b904b3fafb28ea38697211c010d71d321e88452bac085c83a6ea0d0bb7 ;;
    *) echo 'Unsupported synthetic fixture path'; exit 2 ;;
esac
[ -f "$swf" ] || { echo 'Synthetic SWF missing'; exit 2; }
[ "$(sha256sum "$swf" | cut -d ' ' -f 1)" = "$expected_swf" ] \
    || { echo 'Synthetic SWF checksum mismatch'; exit 2; }
[ -x "$test_root/ruffle" ] || { echo 'Ruffle missing'; exit 2; }
[ "$(sha256sum "$test_root/ruffle" | cut -d ' ' -f 1)" = 6814582ba9bbf9a3cdd062b3e7cf1a37043e75d6c752e665aee4edf7c5dec121 ] \
    || { echo 'Ruffle differs from the reviewed nightly'; exit 2; }
loader=$test_root/portable/lib/ld-linux-aarch64.so.1
[ -x "$loader" ] || { echo 'Portable loader missing'; exit 2; }
[ -n "${DISPLAY:-}" ] || { echo 'Weston/XWayland DISPLAY was not supplied'; exit 2; }

run=$test_root/runs/graphics-$(date +%Y%m%d-%H%M%S)-$$
mkdir -p "$run/config" "$run/cache" "$run/saves"
printf '%s\n' "$run" > "$test_root/latest-graphics-run.txt"
printf 'probe=%s\nmovie=%s\nmovieSha256=%s\n' "$probe" "$swf" "$expected_swf" > "$run/probe.txt"

# westonwrap's crusty_x11egl mode supplies its own EGL shim and X display.
# Prefer that verified X11 route over winit choosing the headless compositor's
# Wayland surface. No physical Wayland rendering claim is made by this choice.
unset WAYLAND_DISPLAY
export XDG_SESSION_TYPE=x11
export XKB_CONFIG_ROOT="$test_root/portable/usr/share/X11/xkb"
export ALSA_CONFIG_DIR="$test_root/portable/usr/share/alsa"
export ALSA_CONFIG_PATH="$ALSA_CONFIG_DIR/alsa.conf"
export RUST_LOG=info RUST_LOG_STYLE=never
library_path="$test_root/portable/lib:${LD_LIBRARY_PATH:-}:/usr/trimui/lib:/usr/lib:/lib"
ruffle_pid=
ruffle_token=
watcher_pid=
watcher_token=
process_token() {
    [ -r "/proc/$1/stat" ] || return 0
    awk '{print $22}' "/proc/$1/stat" 2>/dev/null || true
}
same_process() {
    [ -n "$1" ] && [ -n "$2" ] && [ "$(process_token "$1")" = "$2" ]
}
cleanup() {
    if same_process "$watcher_pid" "$watcher_token"; then
        kill "$watcher_pid" 2>/dev/null || true
        wait "$watcher_pid" 2>/dev/null || true
    fi
    if same_process "$ruffle_pid" "$ruffle_token"; then
        kill "$ruffle_pid" 2>/dev/null || true
        sleep 1
        if same_process "$ruffle_pid" "$ruffle_token"; then kill -KILL "$ruffle_pid" 2>/dev/null || true; fi
        wait "$ruffle_pid" 2>/dev/null || true
    fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP

LD_PRELOAD="${DDD_CRUSTY_PRELOAD:?Missing verified graphics shim}" "$loader" --inhibit-cache --library-path "$library_path" "$test_root/ruffle" \
    --graphics gl --no-gui --fullscreen --width 1024 --height 768 --volume 0 \
    --config "$run/config" --cache-directory "$run/cache" \
    --save-directory "$run/saves" --storage disk \
    --tcp-connections deny --open-url-mode deny --filesystem-access-mode deny \
    "$swf" > "$run/ruffle.log" 2>&1 &
ruffle_pid=$!
ruffle_token=$(process_token "$ruffle_pid")
(
    sleep "$seconds"
    if same_process "$ruffle_pid" "$ruffle_token"; then
        printf '%s\n' smoke-time-limit > "$run/deadline.txt"
        kill "$ruffle_pid" 2>/dev/null || true
        sleep 2
        if same_process "$ruffle_pid" "$ruffle_token"; then kill -KILL "$ruffle_pid" 2>/dev/null || true; fi
    fi
) &
watcher_pid=$!
watcher_token=$(process_token "$watcher_pid")
set +e
wait "$ruffle_pid"
code=$?
set -e
ruffle_pid=
ruffle_token=
if same_process "$watcher_pid" "$watcher_token"; then kill "$watcher_pid" 2>/dev/null || true; fi
wait "$watcher_pid" 2>/dev/null || true
watcher_pid=
watcher_token=
printf 'exitCode=%s\nprobe=%s\nmovieSha256=%s\n' "$code" "$probe" "$expected_swf" > "$run/result.txt"
printf 'Ruffle probe log: %s/ruffle.log\n' "$run"
exit "$code"
