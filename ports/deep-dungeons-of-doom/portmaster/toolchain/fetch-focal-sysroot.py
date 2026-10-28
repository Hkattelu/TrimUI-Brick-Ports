#!/usr/bin/env python3
"""Collect a private Ubuntu 20.04 ARM64 build sysroot, without installing packages."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from functools import cmp_to_key
import hashlib
import io
import json
import lzma
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import tarfile
import urllib.request

BASE = 'https://ports.ubuntu.com/ubuntu-ports/'
ROOTS = ['libc6-dev', 'linux-libc-dev', 'libfreetype6-dev', 'libssl-dev',
         'libasound2-dev', 'libudev-dev', 'libfontconfig1-dev', 'liblzma-dev']


def sha(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def download(url, path, expected=None):
    with urllib.request.urlopen(url, timeout=90) as source, path.open('xb') as target:
        shutil.copyfileobj(source, target)
    if expected and sha(path) != expected:
        raise ValueError('Download checksum mismatch: ' + path.name)


def paragraphs(text):
    for block in text.strip().split('\n\n'):
        fields = {}
        for line in block.splitlines():
            if line and not line[0].isspace() and ': ' in line:
                key, value = line.split(': ', 1)
                fields[key] = value
        yield fields


def version_compare(left, right):
    """Debian version ordering for epoch, upstream version and revision."""
    def split(value):
        epoch, rest = value.split(':', 1) if ':' in value else ('0', value)
        upstream, revision = rest.rsplit('-', 1) if '-' in rest else (rest, '0')
        return int(epoch), upstream, revision
    def part(a, b):
        def order(c):
            return -1 if c == '~' else 0 if not c else ord(c) if c.isalpha() else ord(c) + 256
        while a or b:
            while (a and not a[0].isdigit()) or (b and not b[0].isdigit()):
                x, y = (a[0] if a and not a[0].isdigit() else ''), (b[0] if b and not b[0].isdigit() else '')
                if order(x) != order(y):
                    return 1 if order(x) > order(y) else -1
                a, b = a[bool(x):], b[bool(y):]
            x, y = re.match(r'\d*', a)[0], re.match(r'\d*', b)[0]
            nx, ny = x.lstrip('0'), y.lstrip('0')
            if (len(nx), nx) != (len(ny), ny):
                return 1 if (len(nx), nx) > (len(ny), ny) else -1
            a, b = a[len(x):], b[len(y):]
        return 0
    a, b = split(left), split(right)
    return (1 if a[0] > b[0] else -1) if a[0] != b[0] else part(a[1], b[1]) or part(a[2], b[2])


def collect(output):
    output = output.resolve()
    output.mkdir(exist_ok=False)
    indexes, candidates = [], {}
    for suite in ('focal', 'focal-security', 'focal-updates'):
        release = output / (suite + '-InRelease')
        download(BASE + 'dists/' + suite + '/InRelease', release)
        fields = [line.split() for line in release.read_text().split('\nSHA256:\n', 1)[1].split('\nSHA512:', 1)[0].splitlines()]
        index_name = 'main/binary-arm64/Packages.xz'
        digest, size, _ = next(row for row in fields if len(row) == 3 and row[2] == index_name)
        index = output / (suite + '-Packages.xz')
        url = BASE + 'dists/' + suite + '/' + index_name
        download(url, index, digest)
        if index.stat().st_size != int(size):
            raise ValueError('Index size mismatch')
        indexes.append({'suite': suite, 'url': url, 'sha256': digest})
        for row in paragraphs(lzma.decompress(index.read_bytes()).decode()):
            if row.get('Architecture') in ('arm64', 'all') and row.get('Filename'):
                row['suite'] = suite
                candidates.setdefault(row['Package'], []).append(row)
    packages = {name: max(rows, key=cmp_to_key(lambda a, b: version_compare(a['Version'], b['Version'])))
                for name, rows in candidates.items()}
    providers = {}
    for name, row in packages.items():
        for provided in row.get('Provides', '').split(','):
            key = provided.strip().split(' ', 1)[0]
            if key:
                providers.setdefault(key, []).append(name)
    selected, pending = {}, list(ROOTS)
    while pending:
        name = pending.pop()
        if name in selected:
            continue
        row = packages[name]
        selected[name] = row
        for dep in (row.get('Depends', '') + ',' + row.get('Pre-Depends', '')).split(','):
            if not dep.strip():
                continue
            for alternate in dep.split('|'):
                name = re.match(r'\s*([\w.+-]+)', alternate)[1]
                if name in packages or name in providers:
                    pending.append(name if name in packages else sorted(providers[name])[0])
                    break
            else:
                raise ValueError('Unresolved dependency: ' + dep)
    records = [selected[name] for name in sorted(selected)]
    plan = {'roots': ROOTS, 'indexes': indexes, 'packages': records,
            'verification': 'SHA256 checked against HTTPS InRelease and package indexes; signatures not independently verified',
            'compressedBytes': sum(int(row['Size']) for row in records)}
    if plan['compressedBytes'] > 250_000_000:
        raise ValueError('Unexpected sysroot download size')
    (output / 'packages.json').write_text(json.dumps(plan, indent=2) + '\n')
    cache, root = output / 'downloads', output / 'sysroot'
    cache.mkdir()
    (root / 'usr/lib').mkdir(parents=True)
    (root / 'lib').symlink_to('usr/lib')
    def fetch(row):
        path = cache / PurePosixPath(row['Filename']).name
        download(BASE + row['Filename'], path, row['SHA256'])
        return row, path
    links, written = [], 0
    with ThreadPoolExecutor(max_workers=4) as pool:
        for row, archive in pool.map(fetch, records):
            member = next(n for n in subprocess.check_output(['ar', 't', str(archive)], text=True).splitlines() if n.startswith('data.tar'))
            payload = subprocess.check_output(['ar', 'p', str(archive), member])
            with tarfile.open(fileobj=io.BytesIO(payload), mode='r:*') as tar:
                for item in tar:
                    name = item.name.removeprefix('./')
                    if name not in ('lib/ld-linux-aarch64.so.1', 'usr/lib/ld-linux-aarch64.so.1') and not name.startswith((
                            'usr/include/', 'usr/lib/aarch64-linux-gnu/', 'lib/aarch64-linux-gnu/',
                            'usr/lib/pkgconfig/', 'usr/share/pkgconfig/', 'usr/share/doc/')):
                        continue
                    if name.startswith('usr/share/doc/') and not name.endswith(('/copyright', '/copyright.gz')):
                        continue
                    if '..' in PurePosixPath(name).parts or item.isdir():
                        continue
                    target = root / name
                    if not target.resolve().is_relative_to(root):
                        raise ValueError('Package path leaves sysroot')
                    target.parent.mkdir(parents=True, exist_ok=True)
                    if item.issym() or item.islnk():
                        links.append((target, item.linkname, item.islnk()))
                    elif item.isfile():
                        with tar.extractfile(item) as source, target.open('wb') as destination:
                            shutil.copyfileobj(source, destination)
                        target.chmod(item.mode & 0o777)
                        written += item.size
                        if written > 750_000_000:
                            raise ValueError('Unexpected sysroot extraction size')
    for target, name, hard in links:
        destination = root / name.lstrip('/') if name.startswith('/') or hard else target.parent / name
        destination = Path(os.path.normpath(destination))
        if not destination.resolve().is_relative_to(root):
            raise ValueError('Package link leaves sysroot')
        if target.exists() or target.is_symlink():
            target.unlink()
        if hard:
            shutil.copyfile(destination, target)
        else:
            target.symlink_to(os.path.relpath(destination, target.parent))
    # Prevent the compiler's newer libgcc runtime from winning -lgcc_s.
    gcc_runtime = root / 'usr/lib/aarch64-linux-gnu/libgcc_s.so.1'
    if not gcc_runtime.is_file():
        raise ValueError('Missing target libgcc runtime')
    (gcc_runtime.parent / 'libgcc_s.so').symlink_to('libgcc_s.so.1')
    result = {'packages': len(records), 'sysrootBytes': written, 'glibc': selected['libc6']['Version'],
              'sysroot': str(root), 'packageScriptsExecuted': False, 'filesInstalledOnHost': False}
    (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    collect(parser.parse_args().output)
