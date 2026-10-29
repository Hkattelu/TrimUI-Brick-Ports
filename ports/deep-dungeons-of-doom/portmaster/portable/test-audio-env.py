"""Check firmware audio discovery using real Unix sockets and isolated paths."""
import os
from pathlib import Path
import socket
import subprocess
import tempfile

source = Path(__file__).with_name('audio-env.bash')
env = {k: v for k, v in os.environ.items() if not k.startswith(('ALSA_', 'PIPEWIRE_', 'PULSE_'))}


def capture(directories, **changes):
    result = subprocess.run(['bash', '-eu', '-c',
        'source "$1"; shift; ddd_capture_audio_environment "$@"; printf "%s\\0" "${ddd_audio_env[@]}"',
        'audio-test', str(source), *map(str, directories)], env={**env, **changes}, check=True, capture_output=True)
    return dict(word.split('=', 1) for word in result.stdout.decode().split('\0') if word)


def configure(root, directories, **changes):
    result = subprocess.run(['bash', '-eu', '-c',
        'source "$1"; shift; ddd_configure_alsa "$@" >/dev/null; printf "%s\\0" "$ALSA_CONFIG_PATH" "${ALSA_CONFIG_DIR:-}" "${ALSA_PLUGIN_DIR:-}"',
        'audio-test', str(source), str(root), *map(str, directories)], env={**env, **changes}, check=True, capture_output=True)
    return result.stdout.decode().split('\0')[:-1]


with tempfile.TemporaryDirectory(prefix='ddd-audio-') as temporary:
    root = Path(temporary)
    preferred, fallback, absent = (root / name for name in ('preferred', 'fallback', 'absent'))
    for directory in (preferred, fallback):
        (directory / 'pulse').mkdir(parents=True)
    # Regular files are not audio sockets.
    (preferred / 'pipewire-0').touch()
    (preferred / 'pulse/native').touch()
    assert capture([preferred, absent]) == {}
    with socket.socket(socket.AF_UNIX) as pw, socket.socket(socket.AF_UNIX) as pulse:
        pw.bind(str(fallback / 'pipewire-0'))
        pulse.bind(str(fallback / 'pulse/native'))
        expected = {'PIPEWIRE_RUNTIME_DIR': str(fallback), 'PULSE_SERVER': 'unix:' + str(fallback / 'pulse/native')}
        assert capture([preferred, fallback]) == expected
        overrides = {'PIPEWIRE_RUNTIME_DIR': '/chosen/remote', 'PIPEWIRE_REMOTE': 'special',
                     'PULSE_SERVER': 'tcp:chosen', 'ALSA_CARD': 'Speaker',
                     'ALSA_PCM_CARD': 'Chosen', 'ALSA_CTL_CARD': 'Chosen',
                     'ALSA_CONFIG_DIR': '/chosen/alsa', 'ALSA_CONFIG_PATH': '/chosen/config',
                     'ALSA_PLUGIN_DIR': '/chosen/plugins', 'PULSE_SINK': 'headphones'}
        assert capture([fallback], **overrides) == overrides
        assert capture([absent], PULSE_RUNTIME_PATH=str(fallback / 'pulse')) == {
            'PULSE_RUNTIME_PATH': str(fallback / 'pulse'), 'PULSE_SERVER': expected['PULSE_SERVER']}
        assert capture([fallback], PULSE_RUNTIME_PATH='/chosen/pulse', PULSE_COOKIE='/chosen/cookie') == {
            'PULSE_RUNTIME_PATH': '/chosen/pulse', 'PULSE_COOKIE': '/chosen/cookie',
            'PIPEWIRE_RUNTIME_DIR': str(fallback), 'PULSE_SERVER': 'unix:/chosen/pulse/native'}
    (fallback / 'pipewire-0').unlink()
    (fallback / 'pulse/native').unlink()
    with socket.socket(socket.AF_UNIX) as custom:
        custom.bind(str(fallback / 'custom-pipewire'))
        assert capture([fallback], PIPEWIRE_REMOTE='custom-pipewire') == {
            'PIPEWIRE_REMOTE': 'custom-pipewire', 'PIPEWIRE_RUNTIME_DIR': str(fallback)}
    empty, lib64, lib32 = (root / name for name in ('empty', 'lib64', 'lib32'))
    for directory in (empty, lib64, lib32):
        directory.mkdir()
    for directory in (lib64, lib32):
        (directory / 'libasound_module_pcm_pipewire.so').touch()
    assert configure(root, [empty, lib64, lib32]) == [str(root / 'alsa/alsa.conf'), str(root / 'alsa'), str(lib64)]
    assert configure(root, [empty]) == [str(root / 'alsa/alsa.conf'), str(root / 'alsa'), '']
    assert configure(root, [lib64], ALSA_PLUGIN_DIR='/chosen')[-1] == '/chosen'
    assert configure(root, [empty], ALSA_CONFIG_DIR='/chosen')[:2] == ['/chosen/alsa.conf', '/chosen']
    assert configure(root, [empty], ALSA_CONFIG_PATH='/chosen/config')[:2] == ['/chosen/config', '']
print('PASS: socket discovery, firmware fallbacks, custom endpoints/config, plugin layouts and plain ALSA defaults')
