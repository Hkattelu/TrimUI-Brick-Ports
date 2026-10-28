#!/usr/bin/env python3
"""Build a local, unpublished PortMaster preview using explicit input allowlists."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import struct
import zipfile
from license_layout import assemble as assemble_licenses

HERE = Path(__file__).resolve().parent
SOURCES = HERE.parent
GAME_DIRECTORY = 'deepdungeonsofdoom'
MENU = 'Deep Dungeons of Doom.sh'
GAME_HASH = 'df2b4af61a382e112eab5fd7e02db17f562325068621b6bb598fa0e9e9029804'
RUNTIME_HASH = '9df2b904c7e5ffbb31c189ba9431d3197a15c131c7844546994c25fbcbbd85d1'
SOURCE_COMMIT = 'ddb9a7c16792378837d95d62ee69927015882c6f'
PREPARATION = [
    'Prepare-GameCandidate.ps1', 'Prepare-AirLibraryProbe.ps1',
    'Import-Save.ps1', 'Save-Profile.ps1',
    *['diagnostics/offline/' + name + '.ps1' for name in (
        'Prepare-OfflineProbe', 'Prepare-KeyboardMenuProbe',
        'Prepare-WorldMapButtonsProbe', 'Prepare-ShopExtrasButtonsProbe',
        'Prepare-StashButtonsProbe', 'Prepare-DungeonShopButtonsProbe',
        'Prepare-StashFocusProbe', 'Prepare-LocalBackProbe',
        'Prepare-MenuUpWrapProbe', 'Prepare-SilentLogoProbe',
        'Prepare-EncyclopediaBackProbe', 'Prepare-StartupSaveProbe',
        'Prepare-StashDiscardProbe', 'Prepare-AttackConditionGuard',
        'Prepare-AltarButtons', 'Prepare-StashActions', 'Prepare-OfflineExtras')]]


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def ordinary(path, exists=True):
    path = Path(os.path.abspath(path))
    for item in [path, *path.parents]:
        if item.exists() or item.is_symlink():
            info = item.lstat()
            if stat.S_ISLNK(info.st_mode) or getattr(info, 'st_file_attributes', 0) & 0x400:
                raise ValueError('Links and junctions are not package inputs: ' + str(item))
    if exists and not path.exists():
        raise ValueError('Missing input: ' + str(path))
    return path


def relative(name):
    if not re.fullmatch(r'[a-zA-Z0-9_./+-]+', name):
        raise ValueError('Invalid manifest path: ' + name)
    parts = PurePosixPath(name).parts
    if name.startswith('/') or any(p in ('.', '..') for p in name.split('/')) or '' in name.split('/'):
        raise ValueError('Unsafe manifest path: ' + name)
    return parts


def json_bytes(value):
    return (json.dumps(value, indent=2, ensure_ascii=True) + '\n').encode()


def executable(name):
    return name.rsplit('/', 1)[-1] in (
        'ruffle', 'ddd-exit-watch', 'ddd-log-drain', 'ddd-prepare', 'ld-linux-aarch64.so.1')


def write_zip(path, entries):
    with zipfile.ZipFile(path, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for name, data in sorted(entries.items()):
            info = zipfile.ZipInfo(name, date_time=(2026, 10, 27, 0, 0, 0))
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | (0o755 if executable(name) else 0o644)) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, data)
    with zipfile.ZipFile(path) as archive:
        if archive.testzip() is not None or set(archive.namelist()) != set(entries):
            raise ValueError('Archive verification failed.')


def jpeg_size(path):
    data = path.read_bytes()
    if data[:2] != b'\xff\xd8':
        raise ValueError('Supply an original JPEG gameplay capture.')
    at = 2
    while at < len(data):
        if data[at] != 255:
            raise ValueError('Invalid JPEG marker.')
        while at < len(data) and data[at] == 255:
            at += 1
        marker = data[at]
        at += 1
        if marker in (0xD9, 0xDA):
            break
        length = struct.unpack('>H', data[at:at + 2])[0]
        if marker in (0xC0, 0xC1, 0xC2):
            height, width = struct.unpack('>HH', data[at + 3:at + 7])
            return width, height
        if length < 2:
            break
        at += length
    raise ValueError('Could not read JPEG dimensions.')


def build(payload, notices, screenshot, output):
    payload, notices, screenshot = [ordinary(p) for p in (payload, notices, screenshot)]
    output = ordinary(output, exists=False)
    if output.exists() or not output.parent.is_dir():
        raise ValueError('Use a new output directory with an existing parent.')
    for protected in (payload, notices, SOURCES.parent.parent):
        if output == protected or output.is_relative_to(protected):
            raise ValueError('Keep preview output outside inputs and the source checkout.')
    lock = json.loads((HERE / 'payload.lock.json').read_text())
    pins = {}
    for row in lock['files']:
        relative(row['path'])
        if row['path'] in pins or not re.fullmatch('[0-9a-f]{64}', row['sha256']):
            raise ValueError('Invalid or duplicate input pin.')
        pins[row['path']] = row['sha256']
    if pins.get('ddd.swf') != GAME_HASH or pins.get('ruffle') != RUNTIME_HASH:
        raise ValueError('The pin set must identify the accepted game/runtime.')
    supplied = {}
    for line in (ordinary(payload / 'manifest.sha256')).read_text().splitlines():
        match = re.fullmatch(r'([0-9a-f]{64})  ([a-zA-Z0-9_./+-]+)', line)
        if not match or match[2] in supplied:
            raise ValueError('Malformed or duplicate private manifest entry.')
        supplied[match[2]] = match[1]
    if supplied != pins:
        raise ValueError('Prepared payload does not match the pinned input manifest.')
    # Verify every original input, including the private movie, without copying it.
    for name, expected in pins.items():
        path = ordinary(payload / name)
        if not path.is_file() or sha(path) != expected:
            raise ValueError('Input checksum mismatch: ' + name)
    for name in ('launch.sh', 'launcher-common.sh'):
        if sha(SOURCES / 'launcher' / name) != pins[name]:
            raise ValueError('Core source changed; review and regenerate the input pins.')
    inventory = json.loads(ordinary(notices / 'inventory.json').read_text())
    if inventory['sourceCommit'] != SOURCE_COMMIT:
        raise ValueError('Notice inventory is for a different runtime source.')
    notice_files = {}
    for row in inventory['files']:
        relative(row['path'])
        if row['path'] in notice_files:
            raise ValueError('Duplicate notice entry.')
        path = ordinary(notices / row['path'])
        if sha(path) != row['sha256']:
            raise ValueError('Notice checksum mismatch: ' + row['path'])
        notice_files[row['path']] = path
    width, height = jpeg_size(screenshot)
    if (width, height) != (640, 480):
        raise ValueError('Resize the original gameplay capture to exactly 640x480.')
    flat_licenses, license_index = assemble_licenses(inventory, notice_files)
    license_file = SOURCES.parent.parent / 'LICENSE'
    port_license = license_file.read_bytes()
    flat_licenses['LICENSE.port.txt'] = port_license
    license_index['files'].append({'path': 'LICENSE.port.txt', 'component': 'port',
                                  'sha256': hashlib.sha256(port_license).hexdigest(),
                                  'sections': [{'source': 'port/LICENSE', 'offset': 0,
                                                'bytes': len(port_license),
                                                'sha256': hashlib.sha256(port_license).hexdigest()}]})
    metadata = json.loads((HERE / 'port.json').read_text())
    if metadata['name'] != GAME_DIRECTORY + '.zip' or metadata['items'] != [MENU, GAME_DIRECTORY + '/']:
        raise ValueError('Catalogue folder, archive and entry must agree.')
    # All preflight checks precede creation. Nothing overwrites an older preview.
    output.mkdir()
    catalogue = output / 'catalogue' / GAME_DIRECTORY
    game = catalogue / GAME_DIRECTORY
    game.mkdir(parents=True)
    for name in pins:
        if name == 'ddd.swf':
            continue
        target = game / name
        target.parent.mkdir(parents=True, exist_ok=True)
        if name == 'portable/packages.json':
            # The private assembler's original contains local dataArchive paths.
            target.write_bytes(json_bytes(json.loads((SOURCES / 'diagnostics/brick/packages.lock.json').read_text())))
        else:
            shutil.copyfile(payload / name, target)
        target.chmod(0o755 if executable(name) else 0o644)
    updated = {name: sha(game / name) for name in pins if name != 'ddd.swf'}
    updated['ddd.swf'] = GAME_HASH
    (game / 'manifest.sha256').write_text(''.join(f'{updated[name]}  {name}\n' for name in sorted(updated)), newline='\n')
    shutil.copyfile(HERE / MENU, catalogue / MENU)
    (catalogue / MENU).chmod(0o644)
    for name in ('port.json', 'gameinfo.xml'):
        shutil.copyfile(HERE / name, catalogue / name)
    shutil.copyfile(HERE / 'PLAYER-README.md', catalogue / 'README.md')
    shutil.copyfile(screenshot, catalogue / 'screenshot.jpg')
    shutil.copyfile(HERE / 'SOURCE-AND-LICENSES.md', game / 'SOURCE-AND-LICENSES.md')
    shutil.copyfile(HERE / 'RUNTIME-SOURCE.md', game / 'RUNTIME-SOURCE.md')
    for name in ('WESTON-COMPATIBILITY.md', 'MODIFYING-RUNTIME.md', 'refresh-runtime-manifest.py'):
        shutil.copyfile(HERE / name, game / name)
    for name, data in flat_licenses.items():
        target = game / 'licenses' / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    (game / 'license-inventory.json').write_bytes(json_bytes(license_index))
    setup = {name: ordinary(SOURCES / name).read_bytes() for name in PREPARATION}
    setup.update({'README.md': (HERE / 'PLAYER-README.md').read_bytes(), 'LICENSE': license_file.read_bytes()})
    (game / 'setup').mkdir()
    write_zip(game / 'setup/ddd-preparation-tools.zip', setup)
    provenance = {k: lock[k] for k in ('runtimeSourceCommit', 'upstreamCommit', 'runtimeBuildProfile', 'saveOrigin', 'gameVariant')}
    provenance.update({'runtimeSha256': RUNTIME_HASH, 'requiredGameSha256': GAME_HASH,
                       'gameIncluded': False, 'saveIncluded': False, 'hardwareValidated': False,
                       'published': False, 'redistributionReviewComplete': False})
    (game / 'build-provenance.json').write_bytes(json_bytes(provenance))
    entries = {MENU: (catalogue / MENU).read_bytes()}
    entries.update({GAME_DIRECTORY + '/' + p.relative_to(game).as_posix(): p.read_bytes()
                    for p in game.rglob('*') if p.is_file()})
    # PortMaster moves catalogue metadata/artwork into the installed directory.
    # Keep one canonical source copy so its own packager cannot add duplicates.
    entries[GAME_DIRECTORY + '/port.json'] = json.dumps(metadata, indent=4).encode()
    entries[GAME_DIRECTORY + '/gameinfo.xml'] = (catalogue / 'gameinfo.xml').read_bytes()
    entries[GAME_DIRECTORY + '/screenshot.jpg'] = (catalogue / 'screenshot.jpg').read_bytes()
    entries[GAME_DIRECTORY + '/' + GAME_DIRECTORY + '.md'] = (catalogue / 'README.md').read_bytes()
    prohibited = ('.swf', '.sol', '.dll', '.ane', '.log')
    for name in entries:
        if name.lower().endswith(prohibited) or any(part in ('profile', 'save-backups', 'logs') for part in name.split('/')):
            raise ValueError('Private content reached package assembly: ' + name)
    contents = [{'path': name, 'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)} for name, data in sorted(entries.items())]
    contents_bytes = json_bytes({'schema': 1, 'files': contents})
    (game / 'PACKAGE-CONTENTS.json').write_bytes(contents_bytes)
    entries[GAME_DIRECTORY + '/PACKAGE-CONTENTS.json'] = contents_bytes
    archive = output / (GAME_DIRECTORY + '.zip')
    write_zip(archive, entries)
    report = {'schema': 1, 'archive': archive.name, 'sha256': sha(archive), 'bytes': archive.stat().st_size,
              'files': len(entries), 'preparationFiles': len(setup), 'screenshot': [width, height],
              'runtimeSha256': RUNTIME_HASH, 'gameIncluded': False, 'saveIncluded': False,
              'installed': False, 'hardwareValidated': False, 'published': False,
              'redistributionReviewComplete': False, 'missingNotices': inventory['missingNotices']}
    (output / 'preview-report.json').write_bytes(json_bytes(report))
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--payload', type=Path, required=True)
    parser.add_argument('--notices', type=Path, required=True)
    parser.add_argument('--screenshot', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    build(args.payload, args.notices, args.screenshot, args.output)
