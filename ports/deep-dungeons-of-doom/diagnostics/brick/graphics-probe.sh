#!/bin/sh
# Synthetic-only graphics probe, using the selected headless/noop/kiosk/
# crusty_x11egl branch of installed Westonwrap 0.2.8 Preview 1. Deliberately
# starts components directly: no global pkill, /run bind, udev trigger, or
# removal of /tmp/lib from the original multi-platform wrapper.
set -eu
GAMEDIR=/mnt/SDCARD/.ports/ddd-runtime-test-20261024
test_root=${DDD_RUNTIME_ROOT:-$GAMEDIR}
case "$test_root" in /mnt/SDCARD/.ports/ddd-runtime-test-*) ;; *) exit 2 ;; esac
swf=${DDD_TEST_SWF:-$test_root/marker-550x400.swf}
case "$swf" in
    "$test_root/marker-550x400.swf"|"$test_root/stage3d-startup-present.swf") ;;
    *) echo 'Unsupported synthetic fixture path'; exit 2 ;;
esac
runtime=/mnt/SDCARD/Emus/shared/PortMaster/libs/weston_pkg_0.2.squashfs
expected=4c929287617b1276b5cbffcd188eea77aa979a2a84524fd222d03ed3d408c82b
[ "$(sha256sum "$runtime" | cut -d ' ' -f 1)" = "$expected" ] \
    || { echo 'Installed Weston differs from the inspected runtime'; exit 2; }
[ -x "$test_root/run-ruffle-graphics-child.sh" ] || exit 2
[ -f "$swf" ] || exit 2
[ -d /run ] && [ -e /dev/dri/card0 ] || { echo 'Expected firmware paths missing'; exit 2; }

# These global names are fixed by this runtime's XWayland/crusty components.
# Acquire only when absent. Existing /tmp/lib is intentionally left untouched.
for path in /tmp/fonts /tmp/share /tmp/.X11-unix /tmp/.X0-lock /tmp/drmpipe /run/seatd.sock; do
    if [ -e "$path" ] || [ -L "$path" ]; then
        echo "Refusing to replace existing runtime path: $path"
        exit 3
    fi
done
for process in wp_weston seatd virgl_test_server Xwayland; do
    if pidof "$process" >/dev/null 2>&1; then
        echo "Another display process is active: $process"
        exit 3
    fi
done

work=/tmp/ddd-graphics-$$
[ ! -e "$work" ] || exit 3
mkdir "$work"
run=$test_root/runs/weston-$(date +%Y%m%d-%H%M%S)-$$
mkdir -p "$run" "$work/weston" "$work/runtime"
chmod 700 "$work/runtime"
printf '%s\n' "$run" > "$test_root/latest-weston-run.txt"
exec > "$run/session.log" 2>&1
printf 'syntheticMovie=%s\n' "$swf"
mounted=0
fonts_owned=0
share_owned=0
x11_owned=0
fifo_owned=0
seatd_pid=
seatd_token=
weston_pid=
weston_token=
client_pid=
client_token=
deadline_pid=
deadline_token=

process_token() {
    [ -r "/proc/$1/stat" ] || return 0
    awk '{print $22}' "/proc/$1/stat" 2>/dev/null || true
}
remember_descendants() {
    ancestor=$1
    [ -r "/proc/$ancestor/task/$ancestor/children" ] || return 0
    for descendant in $(cat "/proc/$ancestor/task/$ancestor/children"); do
        token=$(process_token "$descendant")
        [ -z "$token" ] || printf '%s %s\n' "$descendant" "$token" >> "$run/weston-children.txt"
        remember_descendants "$descendant"
    done
}
stop_child() {
    pid=$1
    token=$2
    [ -n "$pid" ] && [ -n "$token" ] || return 0
    [ "$(process_token "$pid")" = "$token" ] || return 0
    if kill -0 "$pid" 2>/dev/null; then
        kill -TERM "$pid" 2>/dev/null || true
        count=0
        while [ "$(process_token "$pid")" = "$token" ] && [ "$count" -lt 20 ]; do
            sleep 0.1
            count=$((count + 1))
        done
        [ "$(process_token "$pid")" != "$token" ] || kill -KILL "$pid" 2>/dev/null || true
    fi
    wait "$pid" 2>/dev/null || true
}
cleanup() {
    code=$?
    trap - EXIT INT TERM HUP
    unset LD_PRELOAD
    stop_child "$deadline_pid" "$deadline_token"
    stop_child "$client_pid" "$client_token"
    [ -z "$weston_pid" ] || remember_descendants "$weston_pid"
    stop_child "$weston_pid" "$weston_token"
    if [ -f "$run/weston-children.txt" ]; then
        while read -r saved_pid saved_token; do stop_child "$saved_pid" "$saved_token"; done < "$run/weston-children.txt"
    fi
    stop_child "$seatd_pid" "$seatd_token"
    if [ "$fonts_owned" = 1 ]; then
        [ "$(readlink /tmp/fonts 2>/dev/null || true)" != "$work/weston/fonts" ] || rm -f /tmp/fonts
    fi
    if [ "$share_owned" = 1 ]; then
        [ "$(readlink /tmp/share 2>/dev/null || true)" != "$work/weston/share" ] || rm -f /tmp/share
    fi
    [ "$fifo_owned" = 0 ] || rm -f /tmp/drmpipe
    [ -z "$seatd_pid" ] || rm -f /run/seatd.sock
    if [ "$x11_owned" = 1 ]; then
        rm -f /tmp/.X11-unix/X0 /tmp/.X0-lock
        rmdir /tmp/.X11-unix 2>/dev/null || true
    fi
    # Only our explicitly mounted squashfs path is ever unmounted. A failure
    # leaves it in place for diagnosis; there is no lazy unmount or rm -rf.
    unmounted=not-mounted
    cd /
    if [ "$mounted" = 1 ]; then
        if umount "$work/weston"; then unmounted=yes; else unmounted=no; fi
    fi
    printf 'exitCode=%s\nwestonMountReleased=%s\nworkDirectory=%s\n' "$code" "$unmounted" "$work" > "$run/result.txt"
    rm -f "$work/runtime/wayland-5" "$work/runtime/wayland-5.lock"
    rmdir "$work/weston" "$work/runtime" "$work" 2>/dev/null || true
    exit "$code"
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP

mount -t squashfs -o loop,ro "$runtime" "$work/weston"
mounted=1
weston=$work/weston
libweston=$weston/lib_aarch64/libweston-14
modules=$weston/lib_aarch64/weston
shim=$weston/lib_aarch64/graphics/crusty_x11egl
[ -x "$weston/wp_weston" ] && [ -x "$weston/seatd" ] && [ -f "$shim/libcrusty.so" ] || exit 4

ln -s "$weston/fonts" /tmp/fonts
fonts_owned=1
ln -s "$weston/share" /tmp/share
share_owned=1
mkdir /tmp/.X11-unix
x11_owned=1
chmod 1777 /tmp/.X11-unix
mkfifo /tmp/drmpipe
fifo_owned=1

export WESTON_MODULE_MAP="x11-backend.so=$libweston/x11-backend.so;wayland-backend.so=$libweston/wayland-backend.so;drm-backend.so=$libweston/drm-backend.so;headless-backend.so=$libweston/headless-backend.so;gl-renderer.so=$libweston/gl-renderer.so;kiosk-shell.so=$modules/kiosk-shell.so;desktop-shell.so=$modules/desktop-shell.so;fullscreen-shell.so=$modules/fullscreen-shell.so;xwayland.so=$libweston/xwayland.so;"
export WESTON_DATA_DIR="$weston/data" WESTON_LIBEXEC_DIR="$weston/libexec"
export XDG_RUNTIME_DIR="$work/runtime" XKB_CONFIG_ROOT=/tmp/share/xkb
export WESTON_HEADLESS_WIDTH=1024 WESTON_HEADLESS_HEIGHT=768
export LD_LIBRARY_PATH="$weston/lib_aarch64:/usr/trimui/lib:${LD_LIBRARY_PATH:-}"
export CRUSTY_LIBEGL="$($weston/tools/findlib libEGL.so)"
CRUSTY_LIBSDL=
for library in libSDL2.so libSDL2.so.0 libSDL2-2.0.so libSDL2-2.0.so.0; do
    candidate=$("$weston/tools/findlib" "$library" 2>/dev/null || true)
    if [ -n "$candidate" ]; then CRUSTY_LIBSDL=$(printf '%s\n' "$candidate" | tail -n 1); break; fi
done
export CRUSTY_LIBSDL
[ -n "$CRUSTY_LIBEGL" ] && [ -n "$CRUSTY_LIBSDL" ] || exit 4
gbm=$("$weston/tools/findlib" libgbm.so.1 2>/dev/null || true)
if [ -n "$gbm" ]; then
    export CRUSTY_LIBGBM="$gbm"
    export CRUSTY_LIBDRM="$("$weston/tools/findlib" libdrm.so)"
fi
export CRUSTY_WLMODE=0 CRUSTY_WLDISP=wayland-5 CRUSTY_SHOW_CURSOR=0
export XWAYLAND_LD_LIBRARY_PATH="$weston/lib_aarch64/graphics/mesa_x11_stub:$weston/cm_compat"

# Own every process handle. The whole session has a fallback deadline even if
# XWayland never becomes ready; the child adds its own shorter render deadline.
parent_pid=$$
parent_token=$(process_token "$parent_pid")
(sleep 40; printf 'session-time-limit\n' > "$run/deadline.txt"; [ "$(process_token "$parent_pid")" != "$parent_token" ] || kill -TERM "$parent_pid" 2>/dev/null || true) &
deadline_pid=$!
deadline_token=$(process_token "$deadline_pid")
cd "$weston"
"$weston/seatd" > "$run/seatd.log" 2>&1 &
seatd_pid=$!
seatd_token=$(process_token "$seatd_pid")
sleep 0.5
kill -0 "$seatd_pid" 2>/dev/null || exit 5
"$weston/wp_weston" -c "$weston/weston.ini" -B headless --renderer=noop \
    --shell=kiosk-shell.so -i0 -Swayland-5 --xwayland > "$run/weston.log" 2>&1 &
weston_pid=$!
weston_token=$(process_token "$weston_pid")
count=0
while [ ! -S /tmp/.X11-unix/X0 ]; do
    kill -0 "$weston_pid" 2>/dev/null || exit 6
    [ "$count" -lt 100 ] || { echo 'XWayland readiness deadline'; exit 6; }
    sleep 0.1
    count=$((count + 1))
done
remember_descendants "$weston_pid"

export DISPLAY=:0 WAYLAND_DISPLAY=wayland-5 XDG_SESSION_TYPE=x11
export LD_LIBRARY_PATH="$shim:$weston/lib_aarch64/extra_wayland:$weston/lib_aarch64:/usr/trimui/lib:/usr/lib:/lib"
export DDD_CRUSTY_PRELOAD="$shim/libcrusty.so"
export DDD_RUNTIME_ROOT="$test_root" DDD_TEST_SWF="$swf" DDD_TEST_SECONDS=10
cd "$test_root"
sh "$test_root/run-ruffle-graphics-child.sh" > "$run/child.log" 2>&1 &
client_pid=$!
client_token=$(process_token "$client_pid")
set +e
wait "$client_pid"
code=$?
set -e
client_pid=
client_token=
unset LD_PRELOAD
exit "$code"
