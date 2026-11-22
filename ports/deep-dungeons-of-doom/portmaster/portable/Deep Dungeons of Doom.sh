#!/bin/bash
XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
if [ -d /opt/system/Tools/PortMaster ]; then
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
cd "$GAMEDIR" || { pm_finish; exit 1; }
exec >log.txt 2>&1
if [ -e .save-import.lock ]; then
  pm_message 'Finish the save import before starting DDD.'
  pm_finish
  exit 1
fi
if [ ! -f ddd.swf ]; then
  pm_message 'Preparing DDD from your game files. Please wait.'
fi
chmod +x ddd-prepare
if ! LD_LIBRARY_PATH="$GAMEDIR/libs:${LD_LIBRARY_PATH:-}" ./ddd-prepare >preparation.log 2>&1; then
  pm_message 'DDD setup failed. Copy the complete Windows Steam game into gamedata. See preparation.log for details.'
  pm_finish
  exit 1
fi
source "$GAMEDIR/audio-env.bash"
ddd_capture_audio_environment
weston_runtime=weston_pkg_0.2
if [ ! -f "$controlfolder/libs/${weston_runtime}.squashfs" ]; then
  $ESUDO "$controlfolder/harbourmaster" --quiet --no-check runtime_check weston_pkg_0.2.squashfs
fi
weston_dir=/tmp/ddd-weston
$ESUDO mkdir -p "$weston_dir"
if ! $ESUDO mount "$controlfolder/libs/${weston_runtime}.squashfs" "$weston_dir"; then
  pm_message 'WestonPack could not be mounted.'
  pm_finish
  exit 1
fi

mkdir -p config cache profile
# Weston does not honor an inherited controlfolder on nonstandard firmware paths.
pm_home_bind=
nx_zlib=
if [[ "$CFW_NAME" == TrimUI ]]; then
  # NX's PortMaster zlib exports the inflateValidate version required by Weston libpng.
  if [ -f "$controlfolder/lib/libz.so.1" ]; then
    nx_zlib="$controlfolder/lib/libz.so.1"
  fi
  weston_home="$HOME/.local/share/PortMaster"
  if [[ "$controlfolder" == */Emus/* && ! -f "$weston_home/control.txt" ]]; then
    if [[ "$PM_CAN_MOUNT" == Y && -f "$controlfolder/control.txt" && ! -L "$weston_home" ]] && ! mountpoint -q "$weston_home"; then
      mkdir -p "$controlfolder"
      bind_directories "$weston_home" "$controlfolder"
      if [ -f "$weston_home/control.txt" ]; then
        pm_home_bind="$weston_home"
      fi
    fi
    if [ ! -f "$weston_home/control.txt" ]; then
      pm_message 'WestonPack could not find the NX PortMaster installation.'
      if [[ "$PM_CAN_MOUNT" != "N" ]]; then
        $ESUDO umount "$weston_dir"
      fi
      pm_finish
      exit 1
    fi
  fi
fi
export SDL_GAMECONTROLLERCONFIG="${sdl_controllerconfig:-${SDL_GAMECONTROLLERCONFIG:-}}"
export XWAYLAND_NO_GLAMOR=1 CRUSTY_SHOW_CURSOR=0
chmod +x ruffle ddd-log-drain
pm_platform_helper "$GAMEDIR/ruffle"
# Knulli uses SDL to translate its firmware mapping into a standard Xbox pad.
input_mode=native
case "${CFW_NAME,,}" in
  knulli)
    input_mode=xbox360
    if [ -n "${GPTOKEYB2:-}" ]; then
      echo 'DDD input: SDL virtual Xbox controller (gptokeyb2)'
      $GPTOKEYB2 ruffle -x &
    else
      echo 'DDD input: SDL virtual Xbox controller (gptokeyb)'
      # The older helper does not understand -x; its option is xbox360.
      $GPTOKEYB ruffle xbox360 &
    fi
    ;;
  *)
    echo 'DDD input: direct controller (Gilrs)'
    $GPTOKEYB ruffle &
    ;;
esac
rm -f runtime-status
game_command=(env "${ddd_audio_env[@]}" "DDD_INPUT_MODE=$input_mode" "DDD_NX_ZLIB=$nx_zlib"
  'RUST_LOG=error,ruffle_desktop::app=warn,gilrs=info,gilrs_core=info'
  GILRS_DISABLE_UDEV=1 bash "$GAMEDIR/run-game.sh")
for index in "${!game_command[@]}"; do
  printf -v 'game_command[index]' '%q' "${game_command[index]}"
done
$ESUDO bash "$weston_dir/westonwrap.sh" headless noop kiosk crusty_x11egl \
  "${game_command[@]}"
code=$(cat runtime-status 2>/dev/null || printf 1)
if [ "${PM_CAN_MOUNT:-Y}" != N ]; then
  [ -z "$pm_home_bind" ] || $ESUDO umount "$pm_home_bind"
  $ESUDO umount "$weston_dir"
fi
pm_finish
exit "$code"
