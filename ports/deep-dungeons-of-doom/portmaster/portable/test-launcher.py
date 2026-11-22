"""Exercise portable launch, failure cleanup and path quoting without hardware."""
import os
from pathlib import Path
import shlex
import socket
import subprocess
import tempfile

source = Path(__file__).resolve().parent
for name in ('Deep Dungeons of Doom.sh', 'run-game.sh', 'audio-env.bash'):
    assert b'\r' not in (source / name).read_bytes()
    subprocess.run(['bash', '-n', str(source / name)], check=True)

with tempfile.TemporaryDirectory(prefix='ddd-portable-') as temporary:
    root = Path(temporary)
    game = root / 'roms with spaces/ports/deepdungeonsofdoom'
    game.mkdir(parents=True)
    (game / 'run-game.sh').write_bytes((source / 'run-game.sh').read_bytes())
    (game / 'audio-env.bash').write_bytes((source / 'audio-env.bash').read_bytes())
    control, tools, weston = root / 'Emus/shared/PortMaster', root / 'tools', root / 'weston'
    (control / 'libs').mkdir(parents=True)
    (control / 'libs/weston_pkg_0.2.squashfs').write_bytes(b'fixture')
    tools.mkdir()
    events = root / 'events'
    def script(path, text):
        path.write_text('#!/bin/bash\n' + text)
        path.chmod(0o755)
    (control / 'control.txt').write_text('''
directory=${DDD_TEST_ROMS#/}
CFW_NAME=${DDD_TEST_CFW:-Fixture}
PM_CAN_MOUNT=${DDD_TEST_MOUNTS:-Y}
ESUDO=fixture-sudo
GPTOKEYB='fixture-gamepad -1'
GPTOKEYB2=${DDD_TEST_GPTOKEYB2:-}
DISPLAY_WIDTH=${DDD_TEST_WIDTH:-720}
DISPLAY_HEIGHT=${DDD_TEST_HEIGHT:-720}
export DISPLAY_WIDTH DISPLAY_HEIGHT
get_controls() { echo controls >> "$DDD_TEST_EVENTS"; }
pm_message() { echo "message:$1" >> "$DDD_TEST_EVENTS"; }
pm_platform_helper() { echo platform >> "$DDD_TEST_EVENTS"; }
bind_directories() { mkdir -p "$1"; cp "$2/control.txt" "$1/control.txt"; printf 'bind:%s:%s\n' "$1" "$2" >> "$DDD_TEST_EVENTS"; }
pm_finish() { echo finish >> "$DDD_TEST_EVENTS"; }
''')
    script(tools / 'fixture-sudo', '''
if [ "${DDD_TEST_CLEAR_MODE:-0}" = 1 ]; then
  unset DDD_INPUT_MODE PIPEWIRE_RUNTIME_DIR PIPEWIRE_REMOTE PULSE_SERVER PULSE_RUNTIME_PATH PULSE_SINK
  unset ALSA_CONFIG_DIR ALSA_CONFIG_PATH ALSA_PLUGIN_DIR ALSA_CARD ALSA_PCM_CARD ALSA_CTL_CARD
fi
exec "$@"
''')
    for helper in ('fixture-gamepad', 'fixture-gamepad2'):
        script(tools / helper, r'''
printf '%s\n' "${0##*/}" "$@" > "$DDD_TEST_HELPER"
printf '%s\n' "${CRUSTY_BLOCK_INPUT:-unset}" "${DDD_TEST_PRELOAD:-unset}" > "$DDD_TEST_HELPER_ENV"
''')
    script(tools / 'mount', '''
echo mount >> "$DDD_TEST_EVENTS"
[ "${DDD_TEST_MOUNT_FAIL:-0}" = 0 ] || exit 1
cp "$DDD_TEST_WRAPPER" "$2/westonwrap.sh"
''')
    script(tools / 'umount', 'echo unmount >> "$DDD_TEST_EVENTS"\n')
    wrapper = root / 'westonwrap-fixture'
    script(wrapper, '''
printf '%s\n' "${CRUSTY_BLOCK_INPUT:-unset}" > "$DDD_TEST_WESTON_ENV"
export XDG_RUNTIME_DIR="$DDD_TEST_WESTON_RUNTIME"
case "$DDD_TEST_DRIVER" in
  libmali) export LD_PRELOAD=/fixture/crusty_x11egl//libcrusty.so ;;
  panfrost) export WAYLAND_DISPLAY=wayland-1 XDG_SESSION_TYPE=wayland ;;
esac
if [ "${DDD_TEST_NX:-0}" = 1 ]; then
  shift 4
  command="$*"
else
  command="${@:5}"
fi
# The NX 0.2.8 wrapper checks this after shifting its arguments.
[ -n "$(printf '%s' "${@:5}")" ] || exit 0
eval "$command"
''')
    script(game / 'ruffle', '''
printf '%s\n' "$@" > "$DDD_TEST_ARGS"
printf '%s\n' "$LD_LIBRARY_PATH" > "$DDD_TEST_LIBS"
printf '%s\n' "$DDD_INPUT_MODE" "$CRUSTY_BLOCK_INPUT" "$RUST_LOG" > "$DDD_TEST_INPUT_ENV"
printf '%s\n' "${PIPEWIRE_RUNTIME_DIR:-}" "${PULSE_SERVER:-}" "$XDG_RUNTIME_DIR" \\
  "${ALSA_CONFIG_PATH:-}" "${ALSA_PLUGIN_DIR:-}" "${PIPEWIRE_REMOTE:-}" "${PULSE_SINK:-}" > "$DDD_TEST_AUDIO_ENV"
printf '%s\n' "$LD_PRELOAD" > "$DDD_TEST_ROOT/preloads"
printf '%s\n' "$LD_LIBRARY_PATH" "$XDG_SESSION_TYPE" "$WAYLAND_DISPLAY" > "$DDD_TEST_ROOT/display"
echo runtime >> "$DDD_TEST_EVENTS"
exit "${DDD_TEST_EXIT:-0}"
''')
    # This fixture consumes the pipe, just as the separately tested bounded logger does.
    script(game / 'ddd-log-drain', 'cat > "$1"\n')
    script(game / 'ddd-prepare', '[ -f ddd.swf ] && [ "${DDD_TEST_PREP_FAIL:-0}" = 0 ]\n')
    launcher = root / 'Deep Dungeons of Doom.sh'
    text = (source / launcher.name).read_text()
    assert text.count('weston_dir=/tmp/ddd-weston') == 1
    launcher.write_text(text.replace('weston_dir=/tmp/ddd-weston', 'weston_dir=' + shlex.quote(str(weston))))
    env = {**os.environ, 'HOME': str(root / 'home'), 'PATH': str(tools) + ':' + os.environ['PATH'], 'XDG_DATA_HOME': str(control.parent),
           'DDD_TEST_ROMS': str(game.parent.parent), 'DDD_TEST_EVENTS': str(events),
           'DDD_TEST_WRAPPER': str(wrapper), 'DDD_TEST_ARGS': str(root / 'args'),
           'DDD_TEST_LIBS': str(root / 'libs'), 'DDD_INPUT_MODE': 'auto',
           'DDD_TEST_ROOT': str(root), 'DDD_TEST_HELPER': str(root / 'helper'), 'DDD_TEST_HELPER_ENV': str(root / 'helper-env'),
           'DDD_TEST_WESTON_ENV': str(root / 'weston-env'), 'DDD_TEST_INPUT_ENV': str(root / 'input-env'),
           'DDD_TEST_AUDIO_ENV': str(root / 'audio-env'), 'DDD_TEST_WESTON_RUNTIME': str(root / 'weston-runtime')}
    env.pop('CRUSTY_BLOCK_INPUT', None)
    for key in list(env):
        if key.startswith(('ALSA_', 'PIPEWIRE_', 'PULSE_')) or key == 'XDG_RUNTIME_DIR':
            env.pop(key)
    def run(code, **changes):
        events.write_text('')
        result = subprocess.run(['bash', str(launcher)], env={**env, **changes}, capture_output=True, text=True)
        assert result.returncode == code, (result, (game / 'log.txt').read_text(), (game / 'runtime.log').read_text() if (game / 'runtime.log').exists() else '')
        lines = events.read_text().splitlines()
        assert lines[0] == 'controls' and lines[-1] == 'finish', lines
        return lines
    def input_route(mode, helper, option=None, preload='unset'):
        expected = [helper, '-1', 'ruffle'] + ([option] if option else [])
        assert (root / 'helper').read_text().splitlines() == expected
        assert (root / 'helper-env').read_text().splitlines() == ['unset', preload]
        assert (root / 'weston-env').read_text().splitlines() == ['unset']
        fields = (root / 'input-env').read_text().splitlines()
        assert fields[:2] == [mode, '1' if mode == 'xbox360' else '0'], fields
        assert 'ruffle_desktop::app=warn' in fields[2] and 'gilrs_core=info' in fields[2], fields
    missing = run(1)
    assert 'mount' not in missing
    (game / 'ddd.swf').write_bytes(b'fixture, not a game')
    lock = game / '.save-import.lock'
    lock.write_text('active import')
    assert 'mount' not in run(1)
    assert lock.read_text() == 'active import'
    lock.unlink()
    assert 'mount' not in run(1, DDD_TEST_PREP_FAIL='1')
    failed = run(1, DDD_TEST_MOUNT_FAIL='1')
    assert 'runtime' not in failed
    successful = run(0)
    assert successful.count('unmount') == 1 and 'runtime' in successful
    input_route('native', 'fixture-gamepad')
    args = (root / 'args').read_text().splitlines()
    assert args[args.index('--width') + 1] == args[args.index('--height') + 1] == '720'
    assert args[args.index('--save-directory') + 1] == str(game / 'profile')
    assert args[-1] == str(game / 'ddd.swf')
    assert (root / 'libs').read_text().startswith(str(game / 'libs') + ':')
    profile = game / 'profile/sentinel'
    profile.write_bytes(b'keep progress')
    run(27, DDD_TEST_EXIT='27')
    assert profile.read_bytes() == b'keep progress'
    run(0, DDD_TEST_NX='1')
    input_route('native', 'fixture-gamepad')
    # Reproduce the NX wrapper's separate HOME lookup and firmware zlib path.
    (control / 'lib').mkdir()
    (control / 'lib/libz.so.1').touch()
    failed = run(1, DDD_TEST_CFW='TrimUI', DDD_TEST_MOUNTS='N')
    assert not any(line.startswith('bind:') for line in failed)
    assert not (root / 'home/.local/share/PortMaster').exists()
    run(0, DDD_TEST_CFW='TrimUI', DDD_TEST_NX='1')
    assert str(control / 'lib/libz.so.1') in (root / 'preloads').read_text()
    assert any(line.startswith('bind:') for line in events.read_text().splitlines())
    for driver, width, height in [('libmali', '640', '480'), ('panfrost', '1280', '720')]:
        run(0, DDD_TEST_CFW='ROCKNIX', DDD_TEST_DRIVER=driver, DDD_TEST_WIDTH=width, DDD_TEST_HEIGHT=height)
        args = (root / 'args').read_text().splitlines()
        assert '--fullscreen' in args
        assert args[args.index('--width') + 1] == width and args[args.index('--height') + 1] == height
        assert (root / 'preloads').read_text().startswith('./libddd_alsa_poll_recovery.so')

        libpath, session, wayland = (root / 'display').read_text().splitlines()
        assert (str(game / 'libs/crusty') in libpath) == (driver == 'libmali')
        assert (session, wayland) == (('x11', '') if driver == 'libmali' else ('wayland', 'wayland-1'))
        assert 'libz.so.1' not in (root / 'preloads').read_text()
    modern_helper = 'env DDD_TEST_PRELOAD=preserved fixture-gamepad2 -1'
    run(0, DDD_TEST_CFW='Knulli', DDD_TEST_GPTOKEYB2=modern_helper)
    input_route('xbox360', 'fixture-gamepad2', '-x', preload='preserved')
    run(0, DDD_TEST_CFW='knulli')
    input_route('xbox360', 'fixture-gamepad', 'xbox360')
    run(0, DDD_TEST_CFW='knulli', DDD_TEST_GPTOKEYB2=modern_helper, DDD_TEST_CLEAR_MODE='1')
    input_route('xbox360', 'fixture-gamepad2', '-x', preload='preserved')

    audio_runtime = root / "audio ' $(false)"
    (audio_runtime / 'pulse').mkdir(parents=True)
    with socket.socket(socket.AF_UNIX) as pipewire, socket.socket(socket.AF_UNIX) as pulse:
        pipewire.bind(str(audio_runtime / 'pipewire-0'))
        pulse.bind(str(audio_runtime / 'pulse/native'))
        run(0, XDG_RUNTIME_DIR=str(audio_runtime), DDD_TEST_CLEAR_MODE='1', DDD_TEST_NX='1')
        audio = (root / 'audio-env').read_text().splitlines()
        assert audio[:4] == [str(audio_runtime), 'unix:' + str(audio_runtime / 'pulse/native'),
                             str(root / 'weston-runtime'), ''], audio
        explicit = {'PIPEWIRE_RUNTIME_DIR': str(root / "custom ' $(false)"),
                    'PIPEWIRE_REMOTE': 'custom-server', 'PULSE_SERVER': 'unix:/custom pulse',
                    'PULSE_SINK': 'chosen sink', 'ALSA_CONFIG_PATH': str(root / 'custom config'),
                    'ALSA_PLUGIN_DIR': str(root / 'custom plugins')}
        run(0, XDG_RUNTIME_DIR=str(audio_runtime), DDD_TEST_CLEAR_MODE='1', **explicit)
        audio = (root / 'audio-env').read_text().splitlines()
        assert audio == [explicit['PIPEWIRE_RUNTIME_DIR'], explicit['PULSE_SERVER'],
                         str(root / 'weston-runtime'), explicit['ALSA_CONFIG_PATH'],
                         explicit['ALSA_PLUGIN_DIR'], explicit['PIPEWIRE_REMOTE'], explicit['PULSE_SINK']], audio
    assert profile.read_bytes() == b'keep progress'
print('PASS: launch/failure cleanup, saved progress, NX quoting, input routes, audio sockets, explicit overrides and sudo environment clearing')
