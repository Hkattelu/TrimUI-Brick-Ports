#!/usr/bin/env python3
"""Download checksum-verified Ubuntu source archives for the pinned native libraries."""
import argparse
import hashlib
import json
import lzma
from pathlib import Path
import re
import urllib.request

BASE = 'https://ports.ubuntu.com/ubuntu-ports/'
HERE = Path(__file__).resolve().parent


def paragraphs(text):
    for paragraph in text.split('\n\n'):
        record = {}
        key = None
        for line in paragraph.splitlines():
            if line.startswith((' ', '\t')) and key:
                record[key] += '\n' + line.strip()
            elif ': ' in line:
                key, value = line.split(': ', 1)
                record[key] = value
            elif line.endswith(':'):
                key = line[:-1]
                record[key] = ''
        if record:
            yield record


def download(url, target, expected=None, size=None):
    if target.exists():
        raise ValueError('Refusing to replace an existing download: ' + str(target))
    request = urllib.request.Request(url, headers={'User-Agent': 'DDD-PortMaster-source-preparation/1'})
    hasher = hashlib.sha256()
    count = 0
    with urllib.request.urlopen(request, timeout=60) as response, target.open('xb') as stream:
        while data := response.read(1024 * 1024):
            count += len(data)
            if size is not None and count > size:
                raise ValueError('Download exceeded its declared size.')
            stream.write(data)
            hasher.update(data)
    digest = hasher.hexdigest()
    if expected is not None and digest != expected or size is not None and count != size:
        raise ValueError('Source checksum/size mismatch: ' + url)
    return digest


def collect(binary_indexes, output):
    locks = json.loads((HERE.parent / 'diagnostics/brick/packages.lock.json').read_text(encoding='utf-8'))
    indexes = {'noble-updates-Packages': 'noble-updates', 'noble-security-Packages': 'noble-security', 'Packages': 'noble'}
    binary = {}
    for name, suite in indexes.items():
        for row in paragraphs((binary_indexes / name).read_text(encoding='utf-8')):
            binary[(row.get('Package'), row.get('Version'))] = (suite, row)
    wanted = {}
    for lock in locks:
        suite, row = binary[(lock['package'], lock['version'])]
        if row['SHA256'] != lock['sha256']:
            raise ValueError('Binary index does not match pinned package: ' + lock['package'])
        source = row.get('Source', lock['package'])
        match = re.fullmatch(r'([a-z0-9+.-]+)(?: \(([^)]+)\))?', source)
        if not match:
            raise ValueError('Unexpected Source field.')
        name, version = match[1], match[2] or lock['version']
        wanted.setdefault((name, version), []).append(lock['package'])
    collect_records(wanted, ('noble', 'noble-updates', 'noble-security'), output)


def collect_requirements(lock_path, output):
    locks = json.loads(lock_path.read_text(encoding='utf-8'))['packages']
    wanted, suites = {}, set()
    for lock in locks:
        key = (lock['sourcePackage'], lock['sourceVersion'])
        wanted.setdefault(key, []).append(lock['package'])
        suites.update(lock['sourceSuites'])
    if not wanted or not suites <= {'focal', 'focal-updates', 'focal-security', 'noble', 'noble-updates', 'noble-security'}:
        raise ValueError('Invalid source requirements.')
    collect_records(wanted, sorted(suites), output)


def collect_records(wanted, suites, output):
    output.mkdir(exist_ok=False)
    sources = {}
    index_evidence = []
    for suite in suites:
        release = output / (suite + '-InRelease')
        download(BASE + 'dists/' + suite + '/InRelease', release)
        text = release.read_text(encoding='utf-8')
        sha_section = text.split('\nSHA256:\n', 1)[1].split('\nSHA512:', 1)[0]
        fields = [line.split() for line in sha_section.splitlines()]
        match = next(row for row in fields if len(row) == 3 and row[2] == 'main/source/Sources.xz')
        digest, size, path = match
        index = output / (suite + '-Sources.xz')
        url = BASE + 'dists/' + suite + '/' + path
        download(url, index, digest, int(size))
        index_evidence.append({'url': url, 'sha256': digest, 'bytes': int(size)})
        for row in paragraphs(lzma.decompress(index.read_bytes()).decode()):
            key = (row.get('Package'), row.get('Version'))
            if key in wanted:
                sources[key] = row
    absent = sorted(set(wanted) - set(sources))
    if absent:
        (output / 'missing-source-versions.json').write_text(json.dumps(absent, indent=2))
        raise ValueError('Exact source versions absent from current indexes: ' + str(absent))
    records = []
    for key in sorted(wanted):
        row = sources[key]
        directory = output / (key[0] + '_' + key[1].replace(':', '_'))
        directory.mkdir()
        files = []
        for line in row['Checksums-Sha256'].strip().splitlines():
            digest, count, name = line.split()
            if not re.fullmatch('[a-zA-Z0-9_.+~-]+', name):
                raise ValueError('Unexpected source archive name.')
            url = BASE + row['Directory'] + '/' + name
            path = directory / name
            download(url, path, digest, int(count))
            files.append({'file': str(path.relative_to(output)), 'url': url, 'sha256': digest, 'bytes': int(count)})
        record = {'package': key[0], 'version': key[1], 'binaryPackages': sorted(wanted[key]), 'files': files}
        records.append(record)
        print('Verified source: ' + key[0] + ' ' + key[1], flush=True)
    result = {'schema': 1, 'verification': 'Archive SHA256 values match official Ubuntu Sources indexes; compressed indexes match HTTPS InRelease SHA256 fields. OpenPGP signatures were not independently verified.',
              'indexes': index_evidence, 'sources': records, 'published': False}
    (output / 'sources.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'sourcePackages': len(records), 'archives': sum(len(r['files']) for r in records), 'bytes': sum(f['bytes'] for r in records for f in r['files'])}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    inputs = parser.add_mutually_exclusive_group(required=True)
    inputs.add_argument('--binary-indexes', type=Path)
    inputs.add_argument('--requirements-lock', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.requirements_lock:
        collect_requirements(args.requirements_lock, args.output)
    else:
        collect(args.binary_indexes, args.output)
