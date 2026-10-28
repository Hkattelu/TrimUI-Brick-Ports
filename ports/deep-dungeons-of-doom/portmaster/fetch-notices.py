#!/usr/bin/env python3
"""Fetch the pinned upstream notice texts omitted by some published crates."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
import urllib.parse
import urllib.request


def fetch(output):
    lock = Path(__file__).resolve().with_name('notice-supplement.lock.json')
    rows = json.loads(lock.read_text(encoding='utf-8'))
    names = set()
    for row in rows:
        name = row['file']
        if not re.fullmatch(r'[a-zA-Z0-9_./+-]+', name) or name.startswith('/') or any(p in ('', '.', '..') for p in name.split('/')) or name in names:
            raise ValueError('Invalid or duplicate notice path.')
        names.add(name)
        url = urllib.parse.urlparse(row['url'])
        if url.scheme != 'https' or url.netloc not in ('raw.githubusercontent.com', 'codeberg.org', 'gitlab.com'):
            raise ValueError('Unexpected notice provider.')
    output.mkdir(exist_ok=False)

    def get(row):
        target = output / row['file']
        target.parent.mkdir(parents=True, exist_ok=True)
        request = urllib.request.Request(row['url'], headers={'User-Agent': 'DDD-PortMaster-notice-preparation/1'})
        with urllib.request.urlopen(request, timeout=30) as response:
            data = response.read(1024 * 1024 + 1)
        if len(data) > 1024 * 1024 or hashlib.sha256(data).hexdigest() != row['sha256']:
            raise ValueError('Notice content changed: ' + row['url'])
        data.decode('utf-8')
        target.write_bytes(data)
        return row['file']

    with ThreadPoolExecutor(max_workers=4) as workers:
        done = list(workers.map(get, rows))
    (output / 'supplement.json').write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'verifiedNotices': len(done), 'bytes': sum((output / n).stat().st_size for n in done)}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    fetch(args.output)
