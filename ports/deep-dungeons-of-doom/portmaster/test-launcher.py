#!/usr/bin/env python3
"""Host adapter checks with fake platform services. No display, evdev or game."""
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

source = Path(__file__).resolve().parent
core = source.parent / 'launcher'
wrapper = source / 'Deep Dungeons of Doom.sh'
expected_runtime = '4c929287617b1276b5cbffcd188eea77aa979a2a84524fd222d03ed3d408c82b'
for path in [wrapper, *core.glob('*.sh')]:
    assert b'\r' not in path.read_bytes(), path
    subprocess.run(['bash' if path == wrapper else 'sh', '-n', str(path)], check=True)

# NX evaluates conventional GAMEDIR declarations before executing the wrapper.
declarations = re.findall(r'(?m)^\s*(?:export\s+)?GAMEDIR=.*$', wrapper.read_text())
assert len(declarations) == 1 and declarations[0] == 'GAMEDIR="/$directory/ports/deepdungeonsofdoom"'

with tempfile.TemporaryDirectory(prefix='ddd-pm-test-') as directory:
    temp = Path(directory)
    roms = temp / 'roms with spaces'
    game = roms / 'ports/deepdungeonsofdoom'
    game.mkdir(parents=True)
    control = temp / 'PortMaster'
    (control / 'libs').mkdir(parents=True)
    runtime = control / 'libs/weston_pkg_0.2.squashfs'
    runtime.write_text('original runtime fixture')
    events = temp / 'events'
    control.joinpath('control.txt').write_text('''
directory=${DDD_TEST_DIRECTORY#/}
CFW_NAME=Fixture
get_controls() { echo controls >> "$DDD_TEST_EVENTS"; sdl_controllerconfig=fixture-map; }
pm_message() { echo "message:$1" >> "$DDD_TEST_EVENTS"; }
pm_platform_helper() { echo "platform:$1" >> "$DDD_TEST_EVENTS"; }
pm_finish() { echo unexpected-global-finish >> "$DDD_TEST_EVENTS"; }
trap 'echo message-close >> "$DDD_TEST_EVENTS"' EXIT
''')
    control.joinpath('mod_Fixture.txt').write_text('echo mod >> "$DDD_TEST_EVENTS"\n')
    tools = temp / 'bin'
    tools.mkdir()
    real_sha = shutil.which('sha256sum')
    for name, body in {
        'uname': '#!/bin/sh\nprintf "%s\\n" "${DDD_TEST_ARCH:-aarch64}"\n',
        'id': '#!/bin/sh\nprintf "%s\\n" "${DDD_TEST_UID:-0}"\n',
        'sha256sum': f'''#!/bin/sh
if [ "$1" = "$DDD_TEST_RUNTIME" ]; then
 printf '%s  %s\\n' "${{DDD_TEST_RUNTIME_HASH:-{expected_runtime}}}" "$1"
else
 exec "{real_sha}" "$@"
fi
'''
    }.items():
        path = tools / name
        path.write_text(body)
        path.chmod(0o755)
    required = ['launch.sh', 'run-game.sh', 'launcher-common.sh', 'ruffle',
                'ddd-log-drain', 'ddd-exit-watch', 'ddd.swf', 'libddd_alsa_poll_recovery.so',
                'portable/lib/ld-linux-aarch64.so.1']
    for name in required:
        path = game / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('fixture ' + name)
        path.chmod(0o755)
    shutil.copyfile(core / 'launcher-common.sh', game / 'launcher-common.sh')
    (game / 'launch.sh').write_text('''#!/bin/sh
printf 'launch:%s:%s\\n' "$DDD_WESTON_RUNTIME" "$SDL_GAMECONTROLLERCONFIG" >> "$DDD_TEST_EVENTS"
exit 143
''')
    manifest = game / 'manifest.sha256'
    manifest.write_text(''.join(hashlib.sha256((game / name).read_bytes()).hexdigest() + '  ' + name + '\n' for name in required))
    good_manifest = manifest.read_text()
    env = dict(os.environ, PATH=str(tools) + ':' + os.environ['PATH'],
               controlfolder=str(control), DDD_TEST_DIRECTORY=str(roms),
               DDD_TEST_EVENTS=str(events), DDD_TEST_RUNTIME=str(runtime))
    def run(args=(), expected=0, **extra):
        events.write_text('')
        result = subprocess.run(['bash', str(wrapper), *args], env=dict(env, **extra),
                                text=True, capture_output=True, timeout=15)
        assert result.returncode == expected, (result.returncode, result.stdout, result.stderr)
        return result, events.read_text()
    result, log = run(['--check'])
    assert 'integrity passed' in result.stdout and 'controls' not in log and 'launch:' not in log
    assert log.splitlines() == ['mod', 'message-close']
    result, log = run(['--check'], DDD_TEST_RUNTIME_HASH='0bccaeebc11296bb1fe4278c9677cb82965c5a04bcd63745fa09d78228bc1a93')
    assert 'integrity passed' in result.stdout and 'launch:' not in log
    result, log = run(expected=143)
    assert f'launch:{runtime}:fixture-map' in log and 'controls' in log and 'platform:' in log
    assert 'unexpected-global-finish' not in log
    assert log.rstrip().endswith('message-close')
    _, log = run(expected=2, DDD_TEST_ARCH='x86_64')
    assert 'launch:' not in log and 'controls' not in log
    _, log = run(expected=2, DDD_TEST_UID='1000')
    assert 'launch:' not in log
    _, log = run(['--check'], expected=2, DDD_TEST_RUNTIME_HASH='0' * 64)
    assert 'tested WestonPack' in log and 'launch:' not in log
    movie = game / 'ddd.swf'
    movie.rename(game / 'movie.saved')
    _, log = run(expected=2)
    assert 'Game files are required' in log and 'controls' not in log
    (game / 'movie.saved').rename(movie)
    manifest.write_text(good_manifest.replace('ddd.swf', '../ddd.swf'))
    run(['--check'], expected=1)
    manifest.write_text(good_manifest)
    (game / 'ruffle').write_text('corrupt')
    run(['--check'], expected=1)
    run(['--unknown'], expected=2)

    # Apply the NX compatibility rewrites to copies of the actual core scripts.
    # The adapter is intentionally outside the immutable payload manifest.
    for path in core.glob('*.sh'):
        if path.name == 'Deep Dungeons of Doom.sh':
            continue
        original = path.read_text()
        normalized = original
        if '#!/bin/bash' in normalized:
            normalized = re.sub(r'\A[^\n]*', '#!/usr/bin/env bash', normalized)
        normalized = normalized.replace('/roms/ports/PortMaster', str(control))
        normalized = '\n'.join(line if '/usr/trimui/lib' in line else
            re.sub(r'''(LD_LIBRARY_PATH=["'])([^"']*)(["'])''',
                   lambda m: m[1] + m[2] + ':/usr/trimui/lib' + m[3], line)
            for line in normalized.split('\n'))
        assert normalized == original, f'NX would alter an immutable file: {path.name}'

    # Relocated core reaches its own local common file, and refuses bad arguments
    # before inspecting display devices or shared runtime paths.
    relocated = temp / 'relocated core'
    relocated.mkdir()
    for name in ('launch.sh', 'launcher-common.sh'):
        shutil.copyfile(core / name, relocated / name)
    result = subprocess.run(['sh', str(relocated / 'launch.sh'), '--unknown'],
                            capture_output=True, timeout=5)
    assert result.returncode == 2 and b'not found' not in result.stderr
    (relocated / '.save-import.lock').write_text('busy')
    result = subprocess.run(['sh', str(relocated / 'launch.sh')], capture_output=True, timeout=5)
    assert result.returncode == 2 and not result.stderr
print('PortMaster adapter checks passed: setup, relocation, NX rewrites, integrity, refusal and exit propagation; no hardware used.')
