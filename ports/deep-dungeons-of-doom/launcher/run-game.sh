#!/bin/sh
# Internal child of launch.sh; display acquisition belongs to that parent.
set -eu
unset LD_PRELOAD
[ ! -L "$0" ] || exit 2
root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P) || exit 2
. "$root/launcher-common.sh"
[ "$#" = 3 ] || exit 2
run=$1 work=$2 parent_token=$3
case "$run" in "$root"/logs/run-*) ;; *) exit 2 ;; esac
case "$work" in /tmp/ddd-launch-*/game) ;; *) exit 2 ;; esac
[ -d "$run" ] && [ ! -L "$run" ] && [ -d "$work" ] && [ ! -L "$work" ] || exit 2
parent_pid=$(ddd_process_info "$$" | awk '{print $1}')
ddd_live "$parent_pid" "$parent_token" || exit 2
[ -n "${DISPLAY:-}" ] && [ -n "${DDD_CRUSTY_PRELOAD:-}" ] || exit 2
controller=$(ddd_find_controller) || exit 3
loader=$root/portable/lib/ld-linux-aarch64.so.1
swf=$root/ddd.swf
profile=$root/profile
[ -d "$profile" ] && [ ! -L "$profile" ] || exit 2
[ "$(cd "$profile" && pwd -P)" = "$profile" ] || exit 2
[ -z "$(find "$profile" -type l -print)" ] || exit 2
mkdir "$run/config" "$run/cache"
# Disable the optional codec fetch before the runtime initializes.
printf 'enable_openh264 = false\n' > "$run/config/preferences.toml"
ruffle_pid='' ruffle_token='' exit_watch_pid='' exit_watch_token=''
cleanup() {
    code=$?
    trap - EXIT INT TERM HUP
    set +e
    unset LD_PRELOAD
    ddd_stop "$ruffle_pid" "$ruffle_token"
    ddd_stop "$exit_watch_pid" "$exit_watch_token"
    [ -z "$ruffle_pid" ] || wait "$ruffle_pid" 2>/dev/null || true
    [ -z "$exit_watch_pid" ] || wait "$exit_watch_pid" 2>/dev/null || true
    ddd_finish_logs "$work"
    printf 'exitCode=%s\n' "$code" > "$run/game-result.txt"
    exit "$code"
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP

unset WAYLAND_DISPLAY
export XDG_SESSION_TYPE=x11
export XKB_CONFIG_ROOT="$root/portable/usr/share/X11/xkb"
export ALSA_CONFIG_DIR="$root/portable/usr/share/alsa"
export ALSA_CONFIG_PATH="$ALSA_CONFIG_DIR/alsa.conf"
export GILRS_DISABLE_UDEV=1 RUST_LOG=warn RUST_LOG_STYLE=never
library_path="$root/portable/lib:${LD_LIBRARY_PATH:-}:/usr/trimui/lib:/usr/lib:/lib"
ddd_start_log ruffle "$work" "$run" "$root"
# Supplying this nonempty map replaces Ruffle's map. Start/Select have no game
# actions; the separate evdev watcher reserves their chord press for quitting.
LD_PRELOAD="$root/libddd_alsa_poll_recovery.so:$DDD_CRUSTY_PRELOAD" \
"$loader" --inhibit-cache --library-path "$library_path" "$root/ruffle" \
    --player-runtime air --graphics gl --no-gui --fullscreen --width 1024 --height 768 --volume 0.25 \
    --spoof-url file:///ddd-offline/ddd-offline.swf --base "file://$root/" \
    --config "$run/config" --cache-directory "$run/cache" \
    --save-directory "$profile" --storage disk \
    --tcp-connections deny --open-url-mode deny --filesystem-access-mode deny \
    -B left-trigger=left -B right-trigger=right \
    -B d-pad-up=up -B d-pad-down=down -B d-pad-left=left -B d-pad-right=right \
    -B south=return -B east=escape -B west=space -B north=c \
    "$swf" > "$work/ruffle.pipe" 2>&1 &
ruffle_pid=$!
ruffle_token=$(ddd_child_token "$ruffle_pid" "$$") || exit 4
printf '%s %s\n' "$ruffle_pid" "$ruffle_token" > "$run/game-process.txt"
ddd_start_log exit-watch "$work" "$run" "$root"
"$loader" --inhibit-cache --library-path "$root/portable/lib" "$root/ddd-exit-watch" \
    "$controller" "$ruffle_pid" "$ruffle_token" "$root/ruffle" "$swf" \
    > "$work/exit-watch.pipe" 2>&1 &
exit_watch_pid=$!
exit_watch_token=$(ddd_child_token "$exit_watch_pid" "$$") || exit 4
printf '%s %s\n' "$exit_watch_pid" "$exit_watch_token" > "$run/exit-watch-process.txt"
sleep 0.3
ddd_live "$exit_watch_pid" "$exit_watch_token" && ddd_logs_live "$work" || exit 4
printf 'ready\n' > "$run/game-ready.txt"
while ddd_live "$ruffle_pid" "$ruffle_token"; do
    ddd_live "$parent_pid" "$parent_token" || exit 5
    if ! ddd_live "$exit_watch_pid" "$exit_watch_token" || ! ddd_logs_live "$work"; then
        # Ruffle can close its log pipe or end the watcher while its process is
        # still exiting. Preserve wait's actual status after that bounded race.
        # A failed monitor with a surviving runtime remains an error.
        settle=0
        while ddd_live "$ruffle_pid" "$ruffle_token" && [ "$settle" -lt 10 ]; do
            sleep 0.1
            settle=$((settle + 1))
        done
        if ddd_live "$ruffle_pid" "$ruffle_token"; then exit 5; fi
        break
    fi
    sleep 0.2
done
set +e
wait "$ruffle_pid"
code=$?
set -e
ruffle_pid='' ruffle_token=''
exit "$code"
