#!/usr/bin/env python3
"""Inspect the actual portable ZIP and update overlay without launching a game."""
import argparse
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import stat
import sys
import xml.etree.ElementTree as ET
import zipfile

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('portable_builder', HERE / 'build-package.py')
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


def check(preview, output):
    report = json.loads((preview / 'preview-report.json').read_text())
    archive = preview / report['archive']
    assert builder.preview.sha(archive) == report['sha256']
    output.mkdir(exist_ok=False)
    ports = output / 'roms with spaces/ports'
    ports.mkdir(parents=True)
    folder = builder.preview.GAME_DIRECTORY
    game = ports / folder
    with zipfile.ZipFile(archive) as z:
        names = z.namelist()
        assert len(names) == report['files'] == len(set(n.casefold() for n in names))
        for item in z.infolist():
            name = item.filename
            assert name == builder.preview.MENU or name.startswith(folder + '/')
            assert not name.startswith('/') and '\\' not in name and '..' not in name.split('/')
            assert stat.S_ISREG(item.external_attr >> 16)
            assert not name.lower().endswith(('.swf', '.sol', '.dll', '.ane', '.log'))
            assert not any(p in ('profile', 'save-backups', 'logs') for p in name.split('/'))
            if name.endswith('.sh'):
                assert ((item.external_attr >> 16) & 0o777) == 0o644
                assert b'\r' not in z.read(name)
            target = ports / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(z.read(name))
            target.chmod((item.external_attr >> 16) & 0o777)
        for name in ('ruffle', 'ddd-log-drain', 'ddd-prepare'):
            assert ((z.getinfo(folder + '/' + name).external_attr >> 16) & 0o777) == 0o755
        contents = json.loads(z.read(folder + '/PACKAGE-CONTENTS.json'))['files']
        assert {r['path'] for r in contents} == set(names) - {folder + '/PACKAGE-CONTENTS.json'}
        for row in contents:
            data = z.read(row['path'])
            assert len(data) == row['bytes'] and hashlib.sha256(data).hexdigest() == row['sha256']
        pins = {r['path']: r['sha256'] for r in json.loads((HERE / 'payload.lock.json').read_text())['files']}
        manifest = dict((line.split('  ', 1)[1], line.split('  ', 1)[0])
                        for line in z.read(folder + '/manifest.sha256').decode().splitlines())
        assert manifest == {**pins, 'ddd.swf': builder.GAME_HASH}
        for name, expected in pins.items():
            assert hashlib.sha256(z.read(folder + '/' + name)).hexdigest() == expected
        binaries = {n[len(folder) + 1:] for n in names if z.read(n)[:4] == b'\x7fELF'}
        expected_binaries = {n for n in pins if not n.startswith('alsa/')}
        assert binaries == expected_binaries and len(binaries) == 9
        assert not any(n.rsplit('/', 1)[-1].startswith(('libc.', 'libstdc++', 'libpthread', 'libSDL',
                        'libEGL', 'libGL.', 'libGLX', 'libGLES', 'ld-linux', 'libm.')) for n in names)
        metadata = json.loads(z.read(folder + '/port.json'))
        assert metadata['attr']['min_glibc'] == '2.31'
        assert metadata['attr']['exp'] is False
        assert metadata['items'] == [builder.preview.MENU, folder + '/']
        assert z.read(folder + '/TESTING-MATRIX.md') == (HERE.parent / 'TESTING-MATRIX.md').read_bytes()
        info = ET.fromstring(z.read(folder + '/gameinfo.xml')).find('game')
        assert (ports / info.findtext('path')).is_file() and (ports / info.findtext('image')).is_file()
        assert builder.preview.jpeg_size(game / 'screenshot.jpg') == (640, 480)
        index = json.loads(z.read(folder + '/license-inventory.json'))
        licenses = {n for n in names if n.startswith(folder + '/licenses/')}
        assert licenses == {folder + '/licenses/' + row['path'] for row in index['files']}
        sections = 0
        for row in index['files']:
            assert '/' not in row['path'] and row['path'].startswith('LICENSE.') and row['path'].endswith('.txt')
            data = z.read(folder + '/licenses/' + row['path'])
            assert hashlib.sha256(data).hexdigest() == row['sha256']
            for part in row['sections']:
                original = data[part['offset']:part['offset'] + part['bytes']]
                assert hashlib.sha256(original).hexdigest() == part['sha256']
                sections += 1
        assert not any(n.endswith(('.ps1', '.zip')) for n in names)
        assert folder + '/gamedata/Copy Windows Steam game files here.txt' in names
        # An update must not overwrite purchased data, progress, backups or settings.
        sentinels = ('ddd.swf', 'gamedata/ddd-0.1-SNAPSHOT.swf', 'profile/keep.sol', 'save-backups/keep.sol', 'config/preferences.toml')
        for name in sentinels:
            target = game / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(b'preserve private content')
        for name in names:
            (ports / name).write_bytes(z.read(name))
        assert all((game / n).read_bytes() == b'preserve private content' for n in sentinels)
    result = {'passed': True, 'files': len(names), 'elfFiles': len(binaries), 'licenseFiles': len(licenses),
              'noticeSectionsVerified': sections, 'updatePreserved': True, 'gameStarted': False,
              'deviceContacted': False}
    (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--preview', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    check(**vars(parser.parse_args()))
