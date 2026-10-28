#!/usr/bin/env python3
"""Check an actual preview archive in a disposable Linux install; no game run."""
import argparse
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import xml.etree.ElementTree as ET
import zipfile

sys.dont_write_bytecode = True

HERE = Path(__file__).resolve().parent
MENU = 'Deep Dungeons of Doom.sh'
FOLDER = 'deepdungeonsofdoom'


def checksum(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check(preview, movie, runtime, output):
    report = json.loads((preview / 'preview-report.json').read_text())
    archive = preview / report['archive']
    assert checksum(archive) == report['sha256']
    movie_before, runtime_before = checksum(movie), checksum(runtime)
    assert movie_before == 'df2b4af61a382e112eab5fd7e02db17f562325068621b6bb598fa0e9e9029804'
    assert runtime_before in ('4c929287617b1276b5cbffcd188eea77aa979a2a84524fd222d03ed3d408c82b',
                              '0bccaeebc11296bb1fe4278c9677cb82965c5a04bcd63745fa09d78228bc1a93')
    output.mkdir(exist_ok=False)
    ports = output / 'roms with spaces/ports'
    ports.mkdir(parents=True)
    game = ports / FOLDER
    with zipfile.ZipFile(archive) as z:
        names = z.namelist()
        assert len(names) == len(set(n.casefold() for n in names))
        assert len(names) == report['files'] and MENU in names
        for info in z.infolist():
            name = info.filename
            assert name == MENU or name.startswith(FOLDER + '/')
            assert not name.startswith('/') and '\\' not in name and '..' not in name.split('/')
            assert stat.S_ISREG(info.external_attr >> 16)
            assert not name.lower().endswith(('.swf', '.sol', '.dll', '.ane', '.log'))
            assert not any(p in ('profile', 'save-backups', 'logs') for p in name.split('/'))
            target = ports / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(z.read(name))
            target.chmod((info.external_attr >> 16) & 0o777)
        contents = json.loads(z.read(FOLDER + '/PACKAGE-CONTENTS.json'))
        assert {x['path'] for x in contents['files']} == set(names) - {FOLDER + '/PACKAGE-CONTENTS.json'}
        for row in contents['files']:
            assert checksum(ports / row['path']) == row['sha256']
        assert not (ports / MENU).stat().st_mode & 0o111
        assert all(not ((info.external_attr >> 16) & 0o111)
                   for info in z.infolist() if info.filename.endswith('.sh'))
        assert (game / 'ruffle').stat().st_mode & 0o111
        assert (game / 'portable/lib/ld-linux-aarch64.so.1').stat().st_mode & 0o111
        metadata = json.loads(z.read(FOLDER + '/port.json'))
        assert metadata == json.loads((HERE / 'port.json').read_text())
        assert set(metadata['items']) == {MENU, FOLDER + '/'}
        assert z.read(FOLDER + '/' + FOLDER + '.md') == (HERE / 'PLAYER-README.md').read_bytes()
        assert z.read(FOLDER + '/gameinfo.xml') == (HERE / 'gameinfo.xml').read_bytes()
        gameinfo = ET.fromstring(z.read(FOLDER + '/gameinfo.xml')).find('game')
        assert (ports / gameinfo.findtext('path')).is_file()
        assert (ports / gameinfo.findtext('image')).is_file()
        assert FOLDER + '/README.md' not in names
        license_names = [name for name in names if name.startswith(FOLDER + '/licenses/')]
        assert license_names and all(len(name.split('/')) == 3 for name in license_names)
        assert all(name.split('/')[-1].startswith('LICENSE.') and name.endswith('.txt') for name in license_names)
        license_index = json.loads(z.read(FOLDER + '/license-inventory.json'))
        assert {FOLDER + '/licenses/' + row['path'] for row in license_index['files']} == set(license_names)
        for row in license_index['files']:
            data = z.read(FOLDER + '/licenses/' + row['path'])
            assert hashlib.sha256(data).hexdigest() == row['sha256']
            for section in row['sections']:
                original = data[section['offset']:section['offset'] + section['bytes']]
                assert hashlib.sha256(original).hexdigest() == section['sha256']
        with zipfile.ZipFile(io.BytesIO(z.read(FOLDER + '/setup/ddd-preparation-tools.zip'))) as setup:
            spec = importlib.util.spec_from_file_location('builder', HERE / 'build-preview.py')
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            assert module.jpeg_size(game / 'screenshot.jpg') == (640, 480)
            assert set(setup.namelist()) == set(module.PREPARATION) | {'README.md', 'LICENSE'}
            assert not any(n.lower().endswith(('.swf', '.sol', '.dll', '.ane')) for n in setup.namelist())
            for name in module.PREPARATION:
                assert setup.read(name) == (HERE.parent / name).read_bytes()
    packages = json.loads((game / 'portable/packages.json').read_text())
    assert len(packages) == 20 and all('dataArchive' not in row for row in packages)
    assert 'C:\\Users\\' not in (game / 'portable/files.json').read_text()
    manifest = dict((line.split('  ', 1)[1], line.split('  ', 1)[0])
                    for line in (game / 'manifest.sha256').read_text().splitlines())
    assert manifest['ddd.swf'] == movie_before and not (game / 'ddd.swf').exists()
    for name, digest in manifest.items():
        if name != 'ddd.swf':
            assert checksum(game / name) == digest, name
    control = output / 'PortMaster'
    (control / 'libs').mkdir(parents=True)
    (control / 'libs/weston_pkg_0.2.squashfs').symlink_to(runtime.resolve())
    (control / 'control.txt').write_text('directory=${DDD_TEST_DIRECTORY#/}\npm_message() { printf "%s\\n" "$1"; }\n')
    env = dict(os.environ, controlfolder=str(control.resolve()), DDD_TEST_DIRECTORY=str(ports.parent.resolve()))

    def run(expected, *args):
        result = subprocess.run(['bash', str(ports / MENU), *args], env=env, capture_output=True, text=True, timeout=90)
        assert result.returncode == expected, (result.returncode, result.stdout, result.stderr)
        assert not (game / 'logs').exists(), 'Check unexpectedly started a game run.'
        return result

    missing = run(2)
    assert 'Game files are required' in missing.stdout
    shutil.copyfile(movie, game / 'ddd.swf')
    passed = run(0, '--check')
    assert 'integrity passed' in passed.stdout
    # Corrupt only the disposable installed copy; retain the verified source.
    runtime_data = (game / 'ruffle').read_bytes()
    (game / 'ruffle').write_bytes(b'changed' + runtime_data[7:])
    run(1, '--check')
    (game / 'ruffle').write_bytes(runtime_data)
    # Overlay the package as an update and prove that private files survive.
    sentinel = game / 'profile/localhost/ddd-offline/ddd-offline.swf/update-sentinel.sol'
    sentinel.parent.mkdir(parents=True)
    sentinel.write_bytes(b'private progress must survive an archive update')
    backup = game / 'save-backups/retained'
    backup.parent.mkdir()
    backup.write_bytes(b'private retained backup')
    before = {p: checksum(p) for p in (sentinel, backup, game / 'ddd.swf')}
    with zipfile.ZipFile(archive) as z:
        for info in z.infolist():
            target = ports / info.filename
            target.write_bytes(z.read(info.filename))
            target.chmod((info.external_attr >> 16) & 0o777)
    assert all(checksum(p) == expected for p, expected in before.items())
    assert checksum(movie) == movie_before and checksum(runtime) == runtime_before
    result = {'passed': True, 'archiveSha256': report['sha256'], 'archiveFiles': len(names),
              'installedMetadataPresent': True, 'missingGameRefused': True,
              'realManifestPassed': True, 'corruptRuntimeRefused': True,
              'updatePreservedMovieProfileBackup': True, 'sourceInputsUnchanged': True,
              'gameExecuted': False, 'deviceContacted': False, 'hardwareValidated': False}
    (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--preview', type=Path, required=True)
    parser.add_argument('--private-game', type=Path, required=True)
    parser.add_argument('--weston-runtime', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    check(args.preview, args.private_game, args.weston_runtime, args.output)
