"""Exercise portable launch, failure cleanup and path quoting without hardware."""
import os
from pathlib import Path
import shlex
import subprocess
import tempfile

source = Path(__file__).resolve().parent
for name in ('Deep Dungeons of Doom.sh', 'run-game.sh'):
    assert b'\r' not in (source / name).read_bytes()
    subprocess.run(['bash', '-n', str(source / name)], check=True)

with tempfile.TemporaryDirectory(prefix='ddd-portable-') as temporary:
    root = Path(temporary)
    game = root / 'roms with spaces/ports/deepdungeonsofdoom'
    game.mkdir(parents=True)
    (game / 'run-game.sh').write_bytes((source / 'run-game.sh').read_bytes())
    control, tools, weston = root / 'PortMaster', root / 'tools', root / 'weston'
    (control / 'libs').mkdir(parents=True)
    (control / 'libs/weston_pkg_0.2.squashfs').write_bytes(b'fixture')
    tools.mkdir()
    events = root / 'events'
    def script(path, text):
        path.write_text('#!/bin/bash\n' + text)
        path.chmod(0o755)
    (control / 'control.txt').write_text('''
directory=${DDD_TEST_ROMS#/}
CFW_NAME=Fixture
PM_CAN_MOUNT=Y
ESUDO=fixture-sudo
GPTOKEYB=fixture-gamepad
DISPLAY_WIDTH=720
DISPLAY_HEIGHT=720
export DISPLAY_WIDTH DISPLAY_HEIGHT
get_controls() { echo controls >> "$DDD_TEST_EVENTS"; }
pm_message() { echo "message:$1" >> "$DDD_TEST_EVENTS"; }
pm_platform_helper() { echo platform >> "$DDD_TEST_EVENTS"; }
bind_directories() { printf 'bind:%s:%s\n' "$1" "$2" >> "$DDD_TEST_EVENTS"; }
pm_finish() { echo finish >> "$DDD_TEST_EVENTS"; }
''')
    script(tools / 'fixture-sudo', 'exec "$@"\n')
    script(tools / 'fixture-gamepad', 'echo gamepad >> "$DDD_TEST_EVENTS"\n')
    script(tools / 'mount', '''
echo mount >> "$DDD_TEST_EVENTS"
[ "${DDD_TEST_MOUNT_FAIL:-0}" = 0 ] || exit 1
cp "$DDD_TEST_WRAPPER" "$2/westonwrap.sh"
''')
    script(tools / 'umount', 'echo unmount >> "$DDD_TEST_EVENTS"\n')
    wrapper = root / 'westonwrap-fixture'
    script(wrapper, '''
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
    env = {**os.environ, 'HOME': str(root / 'home'), 'PATH': str(tools) + ':' + os.environ['PATH'], 'controlfolder': str(control),
           'DDD_TEST_ROMS': str(game.parent.parent), 'DDD_TEST_EVENTS': str(events),
           'DDD_TEST_WRAPPER': str(wrapper), 'DDD_TEST_ARGS': str(root / 'args'),
           'DDD_TEST_LIBS': str(root / 'libs')}
    def run(code, **changes):
        events.write_text('')
        result = subprocess.run(['bash', str(launcher)], env={**env, **changes}, capture_output=True, text=True)
        assert result.returncode == code, (result, (game / 'log.txt').read_text(), (game / 'runtime.log').read_text() if (game / 'runtime.log').exists() else '')
        lines = events.read_text().splitlines()
        assert lines[0] == 'controls' and lines[-1] == 'finish', lines
        return lines
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
    assert successful.count('unmount') == 2 and 'runtime' in successful
    args = (root / 'args').read_text().splitlines()
    assert args[args.index('--width') + 1] == args[args.index('--height') + 1] == '720'
    assert args[args.index('--save-directory') + 1] == str(game / 'profile')
    assert args[-1] == str(game / 'ddd.swf')
    assert (root / 'libs').read_text().startswith(str(game / 'libs.aarch64') + ':')
    profile = game / 'profile/sentinel'
    profile.write_bytes(b'keep progress')
    run(27, DDD_TEST_EXIT='27')
    assert profile.read_bytes() == b'keep progress'
    run(0, controlfolder='', EMU_DIR=str(control))
    run(0, DDD_TEST_NX='1')
print('PASS: missing data, mount failure, spaces, resolution, save path, exit status, helpers and EMU_DIR')
