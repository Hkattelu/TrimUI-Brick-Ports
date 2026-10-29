#!/usr/bin/env python3
"""Assemble verified source materials without recursing through private work trees."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import stat
import zipfile

HERE = Path(__file__).resolve().parent


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def build(native, runtime, output, weston_egl=None, portable=False):
    if output.exists() or not output.parent.is_dir():
        raise ValueError('Use a new source archive path with an existing parent.')
    entries = {}

    def add(root, name, destination, expected=None):
        if not re.fullmatch('[a-zA-Z0-9_./+~ -]+', name) or any(x in ('', '.', '..') for x in name.split('/')):
            raise ValueError('Invalid source material path.')
        path = root / name
        if not path.resolve().is_relative_to(root.resolve()) or path.is_symlink() or not path.is_file():
            raise ValueError('Missing or linked source material: ' + name)
        for parent in path.parents:
            if parent.is_symlink():
                raise ValueError('Linked source parent.')
            if parent == root:
                break
        actual = sha(path)
        if expected and actual != expected:
            raise ValueError('Source checksum mismatch: ' + name)
        if destination in entries:
            raise ValueError('Duplicate source archive name.')
        entries[destination] = (path, actual)

    native_report = json.loads((native / 'sources.json').read_text(encoding='utf-8'))
    if portable:
        if weston_egl:
            raise ValueError('The portable candidate does not bundle EGL.')
        required = json.loads((HERE / 'toolchain/required-libraries.json').read_text())['packages']
        expected = {(p['sourcePackage'], p['sourceVersion']) for p in required}
        actual = [(p['package'], p['version']) for p in native_report['sources']]
        if set(actual) != expected or len(actual) != len(expected):
            raise ValueError('Portable native sources do not match the required-library lock.')
    elif len(native_report['sources']) != 16:
        raise ValueError('Expected the complete 16-source-package set.')
    add(native, 'sources.json', 'native/sources.json')
    for source in native_report['sources']:
        for item in source['files']:
            name = item['file'].replace('\\', '/')
            add(native, name, 'native/' + name, item['sha256'])
    for index in native_report['indexes']:
        suite = index['url'].split('/dists/', 1)[1].split('/', 1)[0]
        add(native, suite + '-Sources.xz', 'native/indexes/' + suite + '-Sources.xz', index['sha256'])
        add(native, suite + '-InRelease', 'native/indexes/' + suite + '-InRelease')
    runtime_report = json.loads((runtime / 'source-provenance.json').read_text())
    if runtime_report['sourceCommit'] != 'ddb9a7c16792378837d95d62ee69927015882c6f' or not runtime_report['reverseApplyCheckPassed']:
        raise ValueError('Runtime source correspondence check is missing.')
    add(runtime, runtime_report['patch'], 'runtime/' + runtime_report['patch'], runtime_report['patchSha256'])
    add(runtime, 'Cargo.lock', 'runtime/Cargo.lock', runtime_report['cargoLockSha256'])
    for name in ('source-provenance.json', 'Ruffle-LICENSE.md'):
        add(runtime, name, 'runtime/' + name)
    for item in runtime_report['crateSources']:
        add(runtime, item['file'], 'runtime/' + item['file'], item['sha256'])
    if portable:
        for name in ('launcher/ddd-log-drain.c', 'diagnostics/brick/alsa-poll-recovery.c',
                     'diagnostics/brick/egl-shutdown.c', 'diagnostics/brick/test-alsa-recovery.sh'):
            add(HERE.parent, name, 'port/' + name)
        for name in ('build-alsa.sh', 'build-focal-runtime.sh', 'build-freetype.sh', 'build-helpers.sh',
                     'cross-cxx.sh', 'cross-link.sh', 'fetch-focal-sysroot.py', 'README.md',
                     'required-libraries.json', 'LICENSE.OpenSSL.txt', 'LICENSE.Zlib.txt', 'LICENSE.ALSA.txt'):
            add(HERE, 'toolchain/' + name, 'port/portmaster/toolchain/' + name)
        for name in ('Deep Dungeons of Doom.sh', 'run-game.sh', 'audio-env.sh', 'payload.lock.json'):
            add(HERE, 'portable/' + name, 'port/portmaster/portable/' + name)
        for name in ('ddd-prepare.c', 'recipe.h', 'make-recipe.py', 'build.sh', 'test-device.sh', 'README.md'):
            add(HERE, 'portable/preparation/' + name, 'port/portmaster/portable/preparation/' + name)
        add(HERE.parent.parent.parent, 'LICENSE', 'port/LICENSE')
        add(HERE, 'portable/RUNTIME-SOURCE.md', 'README.md')
    else:
        for name in ('launcher/ddd-log-drain.c', 'diagnostics/brick/ddd-exit-watch.c', 'diagnostics/brick/alsa-poll-recovery.c',
                     'diagnostics/brick/egl-shutdown.c', 'diagnostics/brick/build-egl-shutdown.sh', 'diagnostics/brick/EGL-SHUTDOWN.md'):
            add(HERE.parent, name, 'helpers/' + Path(name).name)
        add(HERE.parent.parent.parent, 'LICENSE', 'helpers/LICENSE')
        add(HERE, 'RUNTIME-SOURCE.md', 'README.md')
        add(HERE, 'WESTON-COMPATIBILITY.md', 'WESTON-COMPATIBILITY.md')
        add(HERE, 'MODIFYING-RUNTIME.md', 'MODIFYING-RUNTIME.md')
        add(HERE, 'refresh-runtime-manifest.py', 'refresh-runtime-manifest.py')
    add(HERE, 'common-licenses/Minerva-ISC', 'runtime/Minerva-ISC')
    add(HERE, 'common-licenses/Minerva-SOURCE.json', 'runtime/Minerva-SOURCE.json')
    if weston_egl:
        egl = json.loads((weston_egl / 'egl-provenance.json').read_text())
        if egl['sourcePackage'] != 'libglvnd' or egl['version'] != '1.3.2-1~ubuntu0.20.04.2':
            raise ValueError('Unexpected Weston EGL source package.')
        for row in egl['sources'] + egl['indexes']:
            add(weston_egl, row['file'], 'weston-egl/' + row['file'], row['sha256'])
        for name in ('egl-provenance.json', 'copyright', 'focal-updates-InRelease'):
            add(weston_egl, name, 'weston-egl/' + name)
    with zipfile.ZipFile(output, 'x', compression=zipfile.ZIP_STORED) as archive:
        for name, (path, _) in sorted(entries.items()):
            info = zipfile.ZipInfo(name, date_time=(2026, 10, 27, 0, 0, 0))
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | 0o644) << 16
            with path.open('rb') as src, archive.open(info, 'w') as dst:
                shutil.copyfileobj(src, dst, 1024 * 1024)
    with zipfile.ZipFile(output) as archive:
        if set(archive.namelist()) != set(entries):
            raise ValueError('Source archive has unexpected entries.')
        for name, (path, expected) in entries.items():
            with archive.open(name) as stream:
                if hashlib.file_digest(stream, 'sha256').hexdigest() != expected or sha(path) != expected:
                    raise ValueError('Source archive verification failed: ' + name)
    report = {'archive': output.name, 'sha256': sha(output), 'bytes': output.stat().st_size,
              'files': len(entries), 'nativeSourcePackages': len(native_report['sources']) + bool(weston_egl),
              'runtimeCrateSources': len(runtime_report['crateSources']),
              'allArchivedHashesVerified': True, 'inputsUnchanged': True,
              'gameIncluded': False, 'published': False}
    output.with_suffix('.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native-sources', type=Path, required=True)
    parser.add_argument('--runtime-sources', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--weston-egl', type=Path)
    parser.add_argument('--portable', action='store_true')
    args = parser.parse_args()
    build(args.native_sources, args.runtime_sources, args.output, args.weston_egl, args.portable)
