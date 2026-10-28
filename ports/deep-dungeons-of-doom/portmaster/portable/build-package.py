#!/usr/bin/env python3
"""Assemble the minimal, unpublished Focal candidate from pinned public inputs."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
PM = HERE.parent
sys.path.insert(0, str(PM))
spec = importlib.util.spec_from_file_location('preview', PM / 'build-preview.py')
preview = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preview)
from license_layout import assemble

RUNTIME = '29735ea9dc077bf8e1253da74bde1cb9c71906cde18334d5e4ef6434bfe7f3ab'
GAME_HASH = 'a2700be5d4bdc8c7cd2a9443024af2795b4fd40bc13eede4ce3abef25c876d44'
HELPERS = {
    'ddd-prepare': '4f63e3c9eb30374fbeb698722a181ff47c0ba041c44913db4dc34d178ceec37c',
    'ddd-log-drain': '2aa226ceca8327fafeb26396b95553fda067e8114ae99b80f98d62e8c1808a3a',
    'libddd_alsa_poll_recovery.so': '024b11ac0ce08a069f173a4d09b507c3d4d70bbb6d9e6e0e57864d1c5ef42655',
    'libs.aarch64/libCRU.so': '42b4261f2309b5b30acf08866f8f7826d28ea4569b86012fcee0ac52bd871a76',
}


def build(payload, notices, screenshot, output):
    payload, notices, screenshot = map(preview.ordinary, (payload, notices, screenshot))
    output = preview.ordinary(output, exists=False)
    if output.exists() or not output.parent.is_dir():
        raise ValueError('Use a new output directory with an existing parent.')
    for protected in (payload, notices, PM.parent.parent.parent):
        if output.is_relative_to(protected) or protected.is_relative_to(output):
            raise ValueError('Keep output separate from inputs and source checkout.')
    lock = json.loads((HERE / 'payload.lock.json').read_text())
    requirements = json.loads((PM / 'toolchain/required-libraries.json').read_text())
    pins = {}
    for row in lock['files']:
        name = row['path']
        preview.relative(name)
        if name in pins:
            raise ValueError('Duplicate payload pin: ' + name)
        pins[name] = row['sha256']
    required = {'ruffle': RUNTIME, **HELPERS}
    for package in requirements['packages']:
        for library in package['libraries']:
            required['libs.aarch64/' + library['file']] = library['sha256']
    # Only the explicit binaries and matching ALSA text configuration are admitted.
    if {n: h for n, h in pins.items() if not n.startswith('alsa/')} != required:
        raise ValueError('Payload contains missing, changed or extra native binaries.')
    if 'alsa/alsa.conf' not in pins:
        raise ValueError('Matching ALSA configuration is required.')
    game_files = {}
    for name, expected in pins.items():
        data = preview.ordinary(payload / name).read_bytes()
        if hashlib.sha256(data).hexdigest() != expected:
            raise ValueError('Payload checksum mismatch: ' + name)
        if name.startswith('alsa/'):
            data.decode('utf-8')
            if b'\0' in data:
                raise ValueError('Binary content in ALSA configuration.')
        game_files[name] = data
    inventory = json.loads((notices / 'inventory.json').read_text())
    if inventory['sourceCommit'] != preview.SOURCE_COMMIT or inventory['missingNotices']:
        raise ValueError('Incomplete or mismatched runtime notices.')
    notice_files = {}
    for row in inventory['files']:
        name = row['path']
        preview.relative(name)
        if name.startswith('debian/'):
            continue
        path = preview.ordinary(notices / name)
        if name in notice_files or preview.sha(path) != row['sha256']:
            raise ValueError('Duplicate or changed notice: ' + name)
        notice_files[name] = path
    native_notices = {'libssl1.1': 'OpenSSL', 'zlib1g': 'Zlib', 'alsa-lib': 'ALSA'}
    for package in requirements['packages']:
        component = native_notices[package['package']]
        notice_files['debian/' + package['package'] + '/copyright'] = preview.ordinary(
            PM / ('toolchain/LICENSE.' + component + '.txt'))
    inventory['native'] = requirements['packages']
    flat, index = assemble(inventory, notice_files)
    port_license = preview.ordinary(preview.SOURCES.parent.parent / 'LICENSE').read_bytes()
    flat['LICENSE.port.txt'] = port_license
    index['files'].append({'path': 'LICENSE.port.txt', 'component': 'port',
                          'sha256': hashlib.sha256(port_license).hexdigest(), 'sections': []})
    game_files.update({'licenses/' + name: data for name, data in flat.items()})
    game_files['license-inventory.json'] = preview.json_bytes(index)
    game_files['required-libraries.json'] = preview.json_bytes(requirements)
    for name in ('run-game.sh', 'SOURCE-AND-LICENSES.md', 'RUNTIME-SOURCE.md'):
        game_files[name] = (HERE / name).read_bytes()
    game_files['TESTING-MATRIX.md'] = (PM / 'TESTING-MATRIX.md').read_bytes()
    game_files['manifest.sha256'] = ''.join(f'{h}  {n}\n' for n, h in sorted(
        {**pins, 'ddd.swf': GAME_HASH}.items())).encode()
    provenance = {key: value for key, value in lock.items() if key != 'files'}
    provenance.update(runtimeSha256=RUNTIME, requiredGameSha256=GAME_HASH,
                      gameIncluded=False, saveIncluded=False, published=False,
                      nativeSilentChecksPassed=True, playerAccepted=False, otherFirmwareTested=False)
    game_files['build-provenance.json'] = preview.json_bytes(provenance)
    metadata = json.loads((PM / 'port.json').read_text())
    metadata['attr']['min_glibc'] = '2.31'
    metadata['attr']['inst'] = ('Copy the contents of your purchased Windows Steam game folder, including '
                              'ddd-0.1-SNAPSHOT.swf and META-INF, into deepdungeonsofdoom/gamedata. '
                              'Launch the port to prepare the game automatically. Install WestonPack 0.2 '
                              'through PortMaster. No Windows PC or PowerShell is required.')
    # Testing status belongs in the matrix, not the catalogue's visibility filter.
    metadata['attr']['exp'] = False
    if metadata['name'] != preview.GAME_DIRECTORY + '.zip' or metadata['items'] != [preview.MENU, preview.GAME_DIRECTORY + '/']:
        raise ValueError('Catalogue identity mismatch.')
    if preview.jpeg_size(screenshot) != (640, 480):
        raise ValueError('Artwork must be a 640x480 JPEG gameplay capture.')
    # All input checks precede writing a new output tree.
    output.mkdir()
    catalogue = output / 'catalogue' / preview.GAME_DIRECTORY
    catalogue.mkdir(parents=True)
    game_files['gamedata/Copy Windows Steam game files here.txt'] = (
        'Copy the contents of your purchased Windows Steam installation here, including\n'
        'ddd-0.1-SNAPSHOT.swf and META-INF. Launch the port to prepare them automatically.\n').encode()
    for name, data in {'port.json': json.dumps(metadata, indent=4).encode(), 'gameinfo.xml': (PM / 'gameinfo.xml').read_bytes(),
                       'screenshot.jpg': screenshot.read_bytes(), 'README.md': (HERE / 'PLAYER-README.md').read_bytes(),
                       preview.MENU: (HERE / preview.MENU).read_bytes()}.items():
        (catalogue / name).write_bytes(data)
    for name, data in game_files.items():
        target = catalogue / preview.GAME_DIRECTORY / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    entries = {preview.MENU: (catalogue / preview.MENU).read_bytes()}
    entries.update({preview.GAME_DIRECTORY + '/' + n: d for n, d in game_files.items()})
    for name in ('port.json', 'gameinfo.xml', 'screenshot.jpg', 'README.md'):
        installed = preview.GAME_DIRECTORY + '.md' if name == 'README.md' else name
        entries[preview.GAME_DIRECTORY + '/' + installed] = (catalogue / name).read_bytes()
    for name, data in entries.items():
        if name.lower().endswith(('.swf', '.sol', '.dll', '.ane', '.log')) or any(
                p in ('profile', 'save-backups', 'logs') for p in name.split('/')):
            raise ValueError('Private content reached package: ' + name)
        if name.endswith('.sh') and b'\r' in data:
            raise ValueError('Shell scripts must use LF endings.')
    contents = preview.json_bytes({'schema': 1, 'files': [
        {'path': n, 'sha256': hashlib.sha256(d).hexdigest(), 'bytes': len(d)} for n, d in sorted(entries.items())]})
    entries[preview.GAME_DIRECTORY + '/PACKAGE-CONTENTS.json'] = contents
    (catalogue / preview.GAME_DIRECTORY / 'PACKAGE-CONTENTS.json').write_bytes(contents)
    archive = output / (preview.GAME_DIRECTORY + '.zip')
    preview.write_zip(archive, entries)
    report = {'archive': archive.name, 'sha256': preview.sha(archive), 'bytes': archive.stat().st_size,
              'files': len(entries), 'runtimeSha256': RUNTIME, 'nativePackages': len(requirements['packages']),
              'licenseFiles': len(flat), 'gameIncluded': False, 'saveIncluded': False, 'published': False}
    (output / 'preview-report.json').write_bytes(preview.json_bytes(report))
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('payload', 'notices', 'screenshot', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    build(**vars(parser.parse_args()))
