#!/usr/bin/env python3
"""Fetch the exact Ubuntu EGL dependency and matching source for stock WestonPack."""
import argparse
import hashlib
import importlib.util
import json
import lzma
from pathlib import Path
import subprocess
import tarfile
import io

HERE = Path(__file__).resolve().parent
BASE = 'https://ports.ubuntu.com/ubuntu-ports/'
VERSION = '1.3.2-1~ubuntu0.20.04.2'
LIBRARY_SHA = 'af6b268d80f2b940dbef0df080b51a927ac8ec41d06626eea4151a189e6b75a7'
spec = importlib.util.spec_from_file_location('native_sources', HERE / 'collect-native-sources.py')
native = importlib.util.module_from_spec(spec)
spec.loader.exec_module(native)


def fetch(output):
    output.mkdir(exist_ok=False)
    release = output / 'focal-updates-InRelease'
    native.download(BASE + 'dists/focal-updates/InRelease', release)
    fields = [line.split() for line in release.read_text().split('\nSHA256:\n', 1)[1].split('\nSHA512:', 1)[0].splitlines()]
    indexes = []
    records = {}
    for name in ('main/binary-arm64/Packages.xz', 'main/source/Sources.xz'):
        digest, size, _ = next(row for row in fields if len(row) == 3 and row[2] == name)
        path = output / ('focal-updates-' + name.rsplit('/', 1)[1])
        url = BASE + 'dists/focal-updates/' + name
        native.download(url, path, digest, int(size))
        indexes.append({'file': path.name, 'url': url, 'sha256': digest, 'bytes': int(size)})
        wanted = 'libegl1' if 'Packages' in name else 'libglvnd'
        matches = [r for r in native.paragraphs(lzma.decompress(path.read_bytes()).decode()) if r.get('Package') == wanted and r.get('Version') == VERSION]
        if len(matches) != 1:
            raise ValueError('Pinned EGL package missing from official index: ' + wanted)
        records[wanted] = matches[0]
    binary = records['libegl1']
    deb = output / binary['Filename'].rsplit('/', 1)[1]
    native.download(BASE + binary['Filename'], deb, binary['SHA256'], int(binary['Size']))
    # Read only these two regular files; never extract arbitrary archive paths.
    data = subprocess.check_output(['ar', 'p', str(deb), 'data.tar.xz'])
    wanted = {'./usr/lib/aarch64-linux-gnu/libEGL.so.1.1.0': 'libEGL.so.1',
              './usr/share/doc/libegl1/copyright': 'copyright'}
    extracted = []
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:xz') as archive:
        for member_name, target_name in wanted.items():
            member = archive.getmember(member_name)
            if not member.isfile() or member.size > 1024 * 1024:
                raise ValueError('Unexpected EGL package member.')
            blob = archive.extractfile(member).read()
            digest = hashlib.sha256(blob).hexdigest()
            if target_name == 'libEGL.so.1' and digest != LIBRARY_SHA:
                raise ValueError('EGL does not match the tested NX library.')
            (output / target_name).write_bytes(blob)
            extracted.append({'file': target_name, 'sha256': digest})
    source = records['libglvnd']
    sources = []
    for line in source['Checksums-Sha256'].strip().splitlines():
        digest, size, name = line.split()
        if Path(name).name != name or '/' in name or '\\' in name:
            raise ValueError('Unexpected source archive name.')
        url = BASE + source['Directory'] + '/' + name
        native.download(url, output / name, digest, int(size))
        sources.append({'file': name, 'url': url, 'sha256': digest, 'bytes': int(size)})
    report = {'schema': 1, 'binaryPackage': 'libegl1', 'sourcePackage': 'libglvnd', 'version': VERSION,
              'binary': {'file': deb.name, 'url': BASE + binary['Filename'], 'sha256': binary['SHA256']},
              'indexes': indexes, 'sources': sources, 'extracted': extracted,
              'verification': 'Official HTTPS InRelease hashes verify the indexes, which verify binary and source archives. OpenPGP signatures were not independently verified.',
              'matchesTestedNxLibrary': True, 'published': False}
    (output / 'egl-provenance.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'binaryVerified': True, 'sourceArchivesVerified': len(sources), 'eglSha256': LIBRARY_SHA}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    fetch(parser.parse_args().output)
