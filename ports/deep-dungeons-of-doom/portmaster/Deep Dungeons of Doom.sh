#!/usr/bin/env bash
# PortMaster menu adapter. Game files and persistent saves are supplied locally.
# Keep one conventional GAMEDIR assignment: NX's Ports runner reads it as data.

ddd_mode=play
case "$#" in
    0) ;;
    1) [ "$1" = --check ] || exit 2; ddd_mode=check ;;
    *) exit 2 ;;
esac

ddd_control=''
for ddd_path in "${controlfolder:-}" "${EMU_DIR:-}" "/PortMaster" \
    "/opt/system/Tools/PortMaster" "/opt/tools/PortMaster" \
    "${XDG_DATA_HOME:-${HOME:-/tmp}/.local/share}/PortMaster" "/roms/ports/PortMaster" \
    "/mnt/SDCARD/Emus/shared/PortMaster" "/mnt/SDCARD/Apps/PortMaster/PortMaster"; do
    if [ -n "$ddd_path" ] && [ -f "$ddd_path/control.txt" ]; then
        ddd_control=$ddd_path
        break
    fi
done
if [ -z "$ddd_control" ]; then
    printf '%s\n' 'PortMaster was not found. Start this game through your firmware Ports menu.' >&2
    exit 2
fi
# PortMaster scripts are trusted platform configuration and may use unset vars
# or nonzero probes. Do not impose errexit/nounset on them.
source "$ddd_control/control.txt"
# Some control.txt versions reset this to their platform-specific installation.
controlfolder=${controlfolder:-$ddd_control}
if [ ! -f "$controlfolder/control.txt" ]; then controlfolder=$ddd_control; fi
if [ -f "$controlfolder/mod_${CFW_NAME:-}.txt" ]; then
    source "$controlfolder/mod_${CFW_NAME:-}.txt"
fi
if [ -z "${directory:-}" ]; then
    printf '%s\n' 'PortMaster did not provide its ports directory.' >&2
    exit 2
fi
GAMEDIR="/$directory/ports/deepdungeonsofdoom"
if [ ! -d "$GAMEDIR" ] || [ -L "$GAMEDIR" ]; then
    printf '%s\n' 'Deep Dungeons of Doom is missing its deepdungeonsofdoom folder.' >&2
    exit 2
fi
ddd_game_root=$(CDPATH='' cd -- "$GAMEDIR" && pwd -P) || exit 2
ddd_message() {
    if declare -F pm_message >/dev/null; then pm_message "$1"; else printf '%s\n' "$1" >&2; fi
}
if [ ! -f "$ddd_game_root/ddd.swf" ] || [ -L "$ddd_game_root/ddd.swf" ]; then
    ddd_message 'Game files are required. Follow deepdungeonsofdoom.md to prepare your purchased Windows copy, then copy ddd.swf into deepdungeonsofdoom.'
    exit 2
fi
export DDD_WESTON_RUNTIME="$controlfolder/libs/weston_pkg_0.2.squashfs"
if [ ! -f "$DDD_WESTON_RUNTIME" ]; then
    ddd_message 'Install the WestonPack 0.2 runtime through PortMaster, then launch DDD again.'
    exit 2
fi
case "$(sha256sum "$DDD_WESTON_RUNTIME" | cut -d ' ' -f1)" in
    4c929287617b1276b5cbffcd188eea77aa979a2a84524fd222d03ed3d408c82b|0bccaeebc11296bb1fe4278c9677cb82965c5a04bcd63745fa09d78228bc1a93) ;;
    *)
    ddd_message 'This build needs the tested WestonPack 0.2 runtime revision. See deepdungeonsofdoom.md before changing runtimes.'
    exit 2
    ;;
esac
if [ "$ddd_mode" = check ]; then
    ddd_check=$(mktemp -d /tmp/ddd-package-check.XXXXXX) || exit 2
    (
        . "$ddd_game_root/launcher-common.sh"
        ddd_validate_manifest "$ddd_game_root" "$ddd_check"
    )
    ddd_code=$?
    # Only remove known validator scratch files; preserve unexpected contents.
    rm -f "$ddd_check/manifest.paths" "$ddd_check/manifest.sorted" "$ddd_check/portable.paths" \
        "$ddd_check/portable.links" "$ddd_check/portable.directories" "$ddd_check/portable.special" \
        "$ddd_check/required.sorted" "$ddd_check/checksums.log"
    rmdir "$ddd_check" 2>/dev/null || true
    [ "$ddd_code" = 0 ] && printf '%s\n' 'DDD installation integrity passed. Graphics, sound and save loading were not tested.'
    exit "$ddd_code"
fi
if [ "$(uname -m)" != aarch64 ] || [ "$(id -u)" != 0 ]; then
    ddd_message 'This preview supports the original TrimUI Brick with NX Redux. Other devices and firmware need validation.'
    exit 2
fi
get_controls || exit 2
export SDL_GAMECONTROLLERCONFIG="${sdl_controllerconfig:-${SDL_GAMECONTROLLERCONFIG:-}}"
if declare -F pm_platform_helper >/dev/null; then pm_platform_helper "$ddd_game_root/ruffle"; fi
# Ruffle uses the tested controller map and its own process-owned exit watcher.
# Do not start gptokeyb or invoke its global process-name cleanup.
unset LD_PRELOAD
sh "$ddd_game_root/launch.sh"
ddd_code=$?
# Keep PortMaster's existing message-close EXIT trap. Display, input and runtime
# cleanup belongs to our child, so pm_finish's global gptokeyb kill is unnecessary.
exit "$ddd_code"
