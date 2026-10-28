#!/bin/sh
# Owns one isolated display session; the menu adapter supplies the runtime path.
set -eu
unset LD_PRELOAD
[ ! -L "$0" ] || exit 2
root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P) || exit 2
[ ! -e "$root/.save-import.lock" ] || exit 2
. "$root/launcher-common.sh"
seconds=0
case "$#" in
    0) ;;
    2)
        [ "$1" = --test-seconds ] || exit 2
        case "$2" in ''|*[!0-9]*) exit 2 ;; esac
        [ "${#2}" -le 3 ] && [ "$2" -ge 1 ] && [ "$2" -le 600 ] || exit 2
        seconds=$2 ;;
    *) exit 2 ;;
esac
runtime=${DDD_WESTON_RUNTIME:?The menu entry must supply the PortMaster Weston runtime}
expected=4c929287617b1276b5cbffcd188eea77aa979a2a84524fd222d03ed3d408c82b
for path in /tmp/fonts /tmp/share /tmp/.X11-unix /tmp/.X0-lock /tmp/drmpipe /run/seatd.sock; do
    if [ -e "$path" ] || [ -L "$path" ]; then ddd_fail "Runtime path is in use: $path"; exit 3; fi
done
for process in wp_weston seatd virgl_test_server Xwayland; do
    if pidof "$process" >/dev/null 2>&1; then ddd_fail "Display process is active: $process"; exit 3; fi
done
[ -d /run ] && [ -e /dev/dri/card0 ] || exit 3
work=/tmp/ddd-launch-$$
mkdir -m 700 "$work"
work_identity=$(ddd_identity "$work")
run='' mounted=0
seatd_pid='' seatd_token='' weston_pid='' weston_token='' client_pid='' client_token=''
fonts_identity='' share_identity='' x11_identity='' fifo_identity=''
seatd_identity='' x0_identity='' xlock_identity='' wayland_identity='' waylock_identity=''
capture_shared_paths() {
    # Capture once, while the original display processes are still ours.
    if ddd_live "$seatd_pid" "$seatd_token"; then
        [ -n "$seatd_identity" ] || seatd_identity=$(ddd_identity /run/seatd.sock 2>/dev/null || true)
    fi
    ddd_live "$weston_pid" "$weston_token" || return 0
    [ -n "$x0_identity" ] || x0_identity=$(ddd_identity /tmp/.X11-unix/X0 2>/dev/null || true)
    [ -n "$xlock_identity" ] || xlock_identity=$(ddd_identity /tmp/.X0-lock 2>/dev/null || true)
    [ -n "$wayland_identity" ] || wayland_identity=$(ddd_identity "$work/runtime/wayland-5" 2>/dev/null || true)
    [ -n "$waylock_identity" ] || waylock_identity=$(ddd_identity "$work/runtime/wayland-5.lock" 2>/dev/null || true)
}
cleanup() {
    code=$?
    trap - EXIT INT TERM HUP
    set +e
    unset LD_PRELOAD LD_LIBRARY_PATH
    capture_shared_paths
    # Allow the child enough time to close Ruffle, its watcher and log readers.
    ddd_stop "$client_pid" "$client_token" 120
    [ -z "$client_pid" ] || wait "$client_pid" 2>/dev/null || true
    if [ -n "$run" ]; then
        ddd_remember_descendants "$weston_pid" "$weston_token" "$run/weston-children.txt"
    fi
    ddd_stop "$weston_pid" "$weston_token"
    if [ -n "$run" ] && [ -f "$run/weston-children.txt" ]; then
        while read -r saved_pid saved_token _saved_parent; do ddd_stop "$saved_pid" "$saved_token"; done < "$run/weston-children.txt"
    fi
    ddd_stop "$seatd_pid" "$seatd_token"
    [ -z "$weston_pid" ] || wait "$weston_pid" 2>/dev/null || true
    [ -z "$seatd_pid" ] || wait "$seatd_pid" 2>/dev/null || true
    ddd_finish_logs "$work"
    ddd_remove /tmp/fonts "$fonts_identity"
    ddd_remove /tmp/share "$share_identity"
    ddd_remove /tmp/drmpipe "$fifo_identity"
    ddd_remove /run/seatd.sock "$seatd_identity"
    ddd_remove /tmp/.X11-unix/X0 "$x0_identity"
    ddd_remove /tmp/.X0-lock "$xlock_identity"
    ddd_remove /tmp/.X11-unix "$x11_identity"
    ddd_remove "$work/runtime/wayland-5" "$wayland_identity"
    ddd_remove "$work/runtime/wayland-5.lock" "$waylock_identity"
    cd /
    released=not-mounted
    if [ "$mounted" = 1 ]; then
        if umount "$work/weston"; then released=yes; else released=no; fi
    fi
    if [ -n "$run" ]; then
        printf 'exitCode=%s\nwestonMountReleased=%s\nworkDirectory=%s\n' "$code" "$released" "$work" > "$run/result.txt"
    fi
    # Never recursively delete a run, profile, mount, or a replacement directory.
    if ddd_same_path "$work" "$work_identity"; then
        rm -f "$work/manifest.paths" "$work/manifest.sorted" "$work/portable.paths" "$work/portable.links" "$work/portable.directories" "$work/portable.special" "$work/required.sorted" "$work/checksums.log" "$work/log-pipes.txt" "$work/log-processes.txt"
        if [ -d "$work/game" ] && [ ! -L "$work/game" ]; then
            rm -f "$work/game/log-pipes.txt" "$work/game/log-processes.txt"
            rmdir "$work/game" 2>/dev/null || true
        fi
        rmdir "$work/weston" "$work/runtime" 2>/dev/null || true
        rmdir "$work" 2>/dev/null || true
    fi
    exit "$code"
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP
ddd_validate_manifest "$root" "$work" || exit 2
runtime_hash=$(sha256sum "$runtime" | cut -d ' ' -f 1)
case "$runtime_hash" in
    "$expected"|0bccaeebc11296bb1fe4278c9677cb82965c5a04bcd63745fa09d78228bc1a93) ;;
    *) ddd_fail 'Weston checksum mismatch'; exit 2 ;;
esac
[ ! -L "$root/logs" ] && [ ! -L "$root/profile" ] || exit 2
mkdir -p "$root/logs" "$root/profile"
run=$root/logs/run-$(date +%Y%m%d-%H%M%S)-$$
mkdir "$run" "$work/weston" "$work/runtime" "$work/game"
chmod 700 "$work/runtime" "$work/game"
exec > "$run/session.log" 2>&1
printf 'testSeconds=%s\n' "$seconds"
mount -t squashfs -o loop,ro "$runtime" "$work/weston"
mounted=1
weston=$work/weston
libweston=$weston/lib_aarch64/libweston-14
modules=$weston/lib_aarch64/weston
shim=$weston/lib_aarch64/graphics/crusty_x11egl
[ -x "$weston/wp_weston" ] && [ -x "$weston/seatd" ] && [ -f "$shim/libcrusty.so" ] || exit 4
ln -s "$weston/fonts" /tmp/fonts
fonts_identity=$(ddd_identity /tmp/fonts)
ln -s "$weston/share" /tmp/share
share_identity=$(ddd_identity /tmp/share)
mkdir /tmp/.X11-unix
x11_identity=$(ddd_identity /tmp/.X11-unix)
chmod 1777 /tmp/.X11-unix
mkfifo /tmp/drmpipe
fifo_identity=$(ddd_identity /tmp/drmpipe)
export WESTON_MODULE_MAP="x11-backend.so=$libweston/x11-backend.so;wayland-backend.so=$libweston/wayland-backend.so;drm-backend.so=$libweston/drm-backend.so;headless-backend.so=$libweston/headless-backend.so;gl-renderer.so=$libweston/gl-renderer.so;kiosk-shell.so=$modules/kiosk-shell.so;desktop-shell.so=$modules/desktop-shell.so;fullscreen-shell.so=$modules/fullscreen-shell.so;xwayland.so=$libweston/xwayland.so;"
export WESTON_DATA_DIR="$weston/data" WESTON_LIBEXEC_DIR="$weston/libexec"
export XDG_RUNTIME_DIR="$work/runtime" XKB_CONFIG_ROOT=/tmp/share/xkb
export WESTON_HEADLESS_WIDTH=1024 WESTON_HEADLESS_HEIGHT=768
export LD_LIBRARY_PATH="$weston/lib_aarch64:/usr/trimui/lib:${LD_LIBRARY_PATH:-}"
CRUSTY_LIBEGL=$("$weston/tools/findlib" libEGL.so)
export CRUSTY_LIBEGL
CRUSTY_LIBSDL=
for library in libSDL2.so libSDL2.so.0 libSDL2-2.0.so libSDL2-2.0.so.0; do
    candidate=$("$weston/tools/findlib" "$library" 2>/dev/null || true)
    if [ -n "$candidate" ]; then CRUSTY_LIBSDL=$(printf '%s\n' "$candidate" | tail -n 1); break; fi
done
export CRUSTY_LIBSDL
[ -n "$CRUSTY_LIBEGL" ] && [ -n "$CRUSTY_LIBSDL" ] || exit 4
gbm=$("$weston/tools/findlib" libgbm.so.1 2>/dev/null || true)
if [ -n "$gbm" ]; then
    CRUSTY_LIBDRM=$("$weston/tools/findlib" libdrm.so)
    export CRUSTY_LIBGBM="$gbm" CRUSTY_LIBDRM
fi
export CRUSTY_WLMODE=0 CRUSTY_WLDISP=wayland-5 CRUSTY_SHOW_CURSOR=0
# Preserve this isolated child path when NX scans and normalizes port scripts.
# Its LD_LIBRARY_PATH rewrite would otherwise also alter XWAYLAND's variable.
xwayland_libraries="$root/portable/xwayland-compat:$weston/lib_aarch64/graphics/mesa_x11_stub:$weston/cm_compat"
export XWAYLAND_LD_LIBRARY_PATH=$xwayland_libraries
cd "$weston"
ddd_start_log seatd "$work" "$run" "$root"
"$weston/seatd" > "$work/seatd.pipe" 2>&1 &
seatd_pid=$!
seatd_token=$(ddd_child_token "$seatd_pid" "$$") || exit 5
count=0
while [ ! -S /run/seatd.sock ]; do
    ddd_live "$seatd_pid" "$seatd_token" && ddd_logs_live "$work" || exit 5
    [ "$count" -lt 50 ] || exit 5
    sleep 0.1
    count=$((count + 1))
done
capture_shared_paths
ddd_start_log weston "$work" "$run" "$root"
"$weston/wp_weston" -c "$weston/weston.ini" -B headless --renderer=noop \
    --shell=kiosk-shell.so -i0 -Swayland-5 --xwayland > "$work/weston.pipe" 2>&1 &
weston_pid=$!
weston_token=$(ddd_child_token "$weston_pid" "$$") || exit 6
count=0
while [ ! -S /tmp/.X11-unix/X0 ]; do
    capture_shared_paths
    ddd_live "$weston_pid" "$weston_token" && ddd_logs_live "$work" || exit 6
    [ "$count" -lt 100 ] || { ddd_fail 'XWayland readiness deadline'; exit 6; }
    sleep 0.1
    count=$((count + 1))
done
capture_shared_paths
ddd_remember_descendants "$weston_pid" "$weston_token" "$run/weston-children.txt"
export DISPLAY=:0 WAYLAND_DISPLAY=wayland-5 XDG_SESSION_TYPE=x11
export LD_LIBRARY_PATH="$shim:$weston/lib_aarch64/extra_wayland:$weston/lib_aarch64:/usr/trimui/lib:/usr/lib:/lib"
export DDD_CRUSTY_PRELOAD="$shim/libcrusty.so"
parent_token=$(ddd_token "$$")
cd "$root"
sh "$root/run-game.sh" "$run" "$work/game" "$parent_token" > "$run/child.log" 2>&1 &
client_pid=$!
client_token=$(ddd_child_token "$client_pid" "$$") || exit 7
started=$(cut -d . -f 1 /proc/uptime)
while ddd_live "$client_pid" "$client_token"; do
    ddd_live "$weston_pid" "$weston_token" && ddd_live "$seatd_pid" "$seatd_token" && ddd_logs_live "$work" || exit 7
    if [ "$seconds" -gt 0 ]; then
        now=$(cut -d . -f 1 /proc/uptime)
        if [ "$((now - started))" -ge "$seconds" ]; then
            printf 'test-time-limit\n' > "$run/test-limit.txt"
            ddd_stop "$client_pid" "$client_token" 120
            break
        fi
    fi
    sleep 0.2
done
set +e
wait "$client_pid"
code=$?
set -e
client_pid='' client_token=''
exit "$code"
