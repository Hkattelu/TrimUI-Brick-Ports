#!/bin/bash
# Keep firmware audio reachable when Weston replaces XDG_RUNTIME_DIR. These
# functions only prepare the game's environment; they never change system audio.
ddd_capture_audio_environment() {
  local dir name value remote=${PIPEWIRE_REMOTE:-pipewire-0}
  local pipewire_dir=${PIPEWIRE_RUNTIME_DIR:-} pulse_server=${PULSE_SERVER:-}
  local -a runtime_dirs=("${XDG_RUNTIME_DIR:-}" "/run/user/$(id -u)" /run /var/run)
  # Optional candidate directories make the same discovery usable in diagnostics.
  [ "$#" = 0 ] || runtime_dirs=("$@")
  if [ -z "$pulse_server" ] && [ -n "${PULSE_RUNTIME_PATH:-}" ]; then
    pulse_server="unix:$PULSE_RUNTIME_PATH/native"
  fi
  for dir in "${runtime_dirs[@]}"; do
    [ -n "$dir" ] || continue
    if [ -z "$pipewire_dir" ] && [ -S "$dir/$remote" ]; then
      pipewire_dir=$dir
    fi
    if [ -z "$pulse_server" ] && [ -S "$dir/pulse/native" ]; then
      pulse_server="unix:$dir/pulse/native"
    fi
  done
  # Weston evaluates a command string and sudo may discard inherited variables.
  # The caller passes these assignments explicitly and shell-quotes every word.
  ddd_audio_env=()
  for name in ALSA_CONFIG_DIR ALSA_CONFIG_PATH ALSA_PLUGIN_DIR ALSA_CARD \
              ALSA_PCM_CARD ALSA_CTL_CARD PIPEWIRE_REMOTE PULSE_RUNTIME_PATH PULSE_SINK PULSE_COOKIE; do
    value=${!name:-}
    [ -z "$value" ] || ddd_audio_env+=("$name=$value")
  done
  [ -z "$pipewire_dir" ] || ddd_audio_env+=("PIPEWIRE_RUNTIME_DIR=$pipewire_dir")
  [ -z "$pulse_server" ] || ddd_audio_env+=("PULSE_SERVER=$pulse_server")
  return 0
}

ddd_configure_alsa() {
  local game_root=$1 dir plugin
  shift
  # Keep the tested ALSA library/configuration pair, including its system and user
  # config hooks. Respect deliberate firmware or user configuration overrides.
  if [ -z "${ALSA_CONFIG_PATH:-}" ]; then
    export ALSA_CONFIG_DIR="${ALSA_CONFIG_DIR:-$game_root/alsa}"
    export ALSA_CONFIG_PATH="$ALSA_CONFIG_DIR/alsa.conf"
  fi
  if [ -z "${ALSA_PLUGIN_DIR:-}" ]; then
    # The bundled library was built with /usr/lib/alsa-lib. Firmware may put
    # 64-bit PipeWire, PulseAudio or other ALSA modules in a different directory.
    # Prefer explicit aarch64/lib64 paths over a possible 32-bit /usr/lib tree.
    [ "$#" != 0 ] || set -- /usr/lib/aarch64-linux-gnu/alsa-lib /usr/lib64/alsa-lib /usr/lib/alsa-lib
    for dir in "$@"; do
      for plugin in "$dir"/libasound_module_pcm_*.so; do
        [ -f "$plugin" ] || continue
        export ALSA_PLUGIN_DIR=$dir
        break 2
      done
    done
  fi
  printf 'DDD audio: ALSA config=%s; plugins=%s; PipeWire runtime=%s; Pulse server=%s\n' \
    "$ALSA_CONFIG_PATH" "${ALSA_PLUGIN_DIR:-library default}" \
    "${PIPEWIRE_RUNTIME_DIR:-session default}" "${PULSE_SERVER:+configured}"
}
