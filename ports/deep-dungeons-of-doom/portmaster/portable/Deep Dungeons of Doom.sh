#!/bin/bash
XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
if [ -f "${controlfolder:-}/control.txt" ]; then
  :
elif [ -f "${EMU_DIR:-}/control.txt" ]; then
  controlfolder=$EMU_DIR
elif [ -d /opt/system/Tools/PortMaster ]; then
  controlfolder=/opt/system/Tools/PortMaster
elif [ -d /opt/tools/PortMaster ]; then
  controlfolder=/opt/tools/PortMaster
elif [ -d "$XDG_DATA_HOME/PortMaster" ]; then
  controlfolder=$XDG_DATA_HOME/PortMaster
else
  controlfolder=/roms/ports/PortMaster
fi
source "$controlfolder/control.txt"
[ -f "$controlfolder/mod_${CFW_NAME}.txt" ] && source "$controlfolder/mod_${CFW_NAME}.txt"
get_controls

GAMEDIR="/$directory/ports/deepdungeonsofdoom"
cd "$GAMEDIR" || exit 1
exec >log.txt 2>&1
if [ -e .save-import.lock ]; then
  pm_message 'Finish the save import before starting DDD.'
  pm_finish
  exit 1
fi
if [ ! -f ddd.swf ]; then
  pm_message 'Prepare your purchased game on the PC and copy ddd.swf here. See deepdungeonsofdoom.md.'
  pm_finish
  exit 1
fi
weston_runtime="$controlfolder/libs/weston_pkg_0.2.squashfs"
if [ ! -f "$weston_runtime" ]; then
  $ESUDO "$controlfolder/harbourmaster" --quiet --no-check runtime_check weston_pkg_0.2.squashfs
fi
weston_dir=/tmp/ddd-weston
$ESUDO mkdir -p "$weston_dir"
if ! $ESUDO mount "$weston_runtime" "$weston_dir"; then
  pm_message 'WestonPack could not be mounted.'
  pm_finish
  exit 1
fi

mkdir -p config cache profile
# Weston does not honor an inherited controlfolder on nonstandard firmware paths.
pm_home_bind=
if [ ! -d /opt/system/Tools/PortMaster ] && [ ! -d /opt/tools/PortMaster ] && \
   [ ! -f "$HOME/.local/share/PortMaster/control.txt" ]; then
  pm_home_bind="$HOME/.local/share/PortMaster"
  bind_directories "$pm_home_bind" "$controlfolder"
fi
export SDL_GAMECONTROLLERCONFIG="${sdl_controllerconfig:-${SDL_GAMECONTROLLERCONFIG:-}}"
export XWAYLAND_NO_GLAMOR=1 CRUSTY_SHOW_CURSOR=0
chmod +x ruffle ddd-log-drain
pm_platform_helper "$GAMEDIR/ruffle"
$GPTOKEYB ruffle -x &
rm -f runtime-status
printf -v game_script '%q' "$GAMEDIR/run-game.sh"
$ESUDO bash "$weston_dir/westonwrap.sh" headless noop kiosk crusty_x11egl \
  env RUST_LOG=error GILRS_DISABLE_UDEV=1 bash "$game_script"
code=$(cat runtime-status 2>/dev/null || printf 1)
if [ "${PM_CAN_MOUNT:-Y}" != N ]; then
  [ -z "$pm_home_bind" ] || $ESUDO umount "$pm_home_bind"
  $ESUDO umount "$weston_dir"
fi
pm_finish
exit "$code"
