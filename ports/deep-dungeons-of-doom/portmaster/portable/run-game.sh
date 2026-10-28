#!/bin/bash
root=$(CDPATH='' cd -- "${BASH_SOURCE[0]%/*}" && pwd -P) || exit 1
cd "$root" || exit 1
unset WAYLAND_DISPLAY
export XDG_SESSION_TYPE=x11
export RUST_LOG_STYLE=never
export RUFFLE_DDD_GC_SLICES=1 RUFFLE_DDD_FLOAT_MIX=1
export RUFFLE_DDD_DRAIN_GAMEPAD=1 RUFFLE_DDD_STAGE3D_PIPELINE_CACHE=1
export RUFFLE_DDD_CONSTANT_RING=1 RUFFLE_DDD_SELECTIVE_BUFFER_BARRIERS=1 RUFFLE_DDD_MERGE_PASSES=1
unset RUFFLE_DDD_TIMING RUFFLE_DDD_AUDIO_TIMING RUFFLE_DDD_CORE_TIMING RUFFLE_DDD_STAGE3D_TIMING
unset RUFFLE_DDD_STAGE3D_BATCHING RUFFLE_DDD_ORDERED_SUBMISSIONS
export LD_LIBRARY_PATH="$root/libs.aarch64:${LD_LIBRARY_PATH:-}"
export ALSA_CONFIG_DIR="$root/alsa" ALSA_CONFIG_PATH="$root/alsa/alsa.conf"
if [ ! -f config/preferences.toml ]; then
  printf 'enable_openh264 = false\n' >config/preferences.toml
fi
rm -f runtime.log
LD_PRELOAD="$root/libddd_alsa_poll_recovery.so:${LD_PRELOAD:-}" "$root/ruffle" \
  --player-runtime air --graphics gl --no-gui --fullscreen \
  --width "${DISPLAY_WIDTH:-640}" --height "${DISPLAY_HEIGHT:-480}" --volume 1 \
  --spoof-url file:///ddd-offline/ddd-offline.swf --base "file://$root/" \
  --config "$root/config" --cache-directory "$root/cache" \
  --save-directory "$root/profile" --storage disk \
  --tcp-connections deny --open-url-mode deny --filesystem-access-mode deny \
  -B left-trigger=left -B right-trigger=right \
  -B d-pad-up=up -B d-pad-down=down -B d-pad-left=left -B d-pad-right=right \
  -B south=return -B east=escape -B west=space -B north=c \
  "$root/ddd.swf" 2>&1 | "$root/ddd-log-drain" "$root/runtime.log" 262144
code=${PIPESTATUS[0]}
printf '%s\n' "$code" >runtime-status
exit "$code"
