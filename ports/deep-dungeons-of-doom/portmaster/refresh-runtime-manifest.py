#!/usr/bin/env python3
"""Prepare a new integrity manifest after local open-source runtime modifications."""
import argparse
import hashlib
from pathlib import Path
import re

ROOT_FILES = {'launch.sh', 'run-game.sh', 'launcher-common.sh', 'ddd-log-drain',
              'ddd-exit-watch', 'ruffle', 'ddd.swf', 'libddd_alsa_poll_recovery.so'}


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        while block := stream.read(1024 * 1024):
            h.update(block)
    return h.hexdigest()


def refresh(root):
    if root.is_symlink() or not root.is_dir():
        raise ValueError('Use a real installation directory, with the game stopped.')
    root = root.resolve(strict=True)
    if (root / '.save-import.lock').exists():
        raise ValueError('A save import is active.')
    manifest = root / 'manifest.sha256'
    output = root / 'manifest.modified.sha256'
    if manifest.is_symlink() or output.exists() or output.is_symlink():
        raise ValueError('Keep the original manifest and use a new output file.')
    previous = {}
    for line in manifest.read_text().splitlines():
        match = re.fullmatch(r'([0-9a-f]{64})  ([a-zA-Z0-9_./+-]+)', line)
        if not match or match[2] in previous:
            raise ValueError('Malformed or duplicate original manifest entry.')
        name = match[2]
        if any(p in ('', '.', '..') for p in name.split('/')) or name.startswith('/'):
            raise ValueError('Unsafe original manifest path.')
        if name not in ROOT_FILES and not name.startswith('portable/'):
            raise ValueError('Unexpected original manifest path.')
        previous[name] = match[1]
    if not ROOT_FILES.issubset(previous):
        raise ValueError('The original manifest is incomplete.')
    portable = root / 'portable'
    if portable.is_symlink() or not portable.is_dir():
        raise ValueError('Missing or linked portable directory.')
    paths = {name: root / name for name in ROOT_FILES}
    for path in portable.rglob('*'):
        if path.is_symlink():
            raise ValueError('Use regular copies for replacement libraries, not links.')
        if path.is_dir():
            continue
        paths[path.relative_to(root).as_posix()] = path
    updated = {}
    for name, path in sorted(paths.items()):
        if not re.fullmatch(r'[a-zA-Z0-9_./+-]+', name) or path.is_symlink() or not path.is_file():
            raise ValueError('Unexpected runtime file: ' + name)
        updated[name] = digest(path)
    if updated['ddd.swf'] != previous['ddd.swf']:
        raise ValueError('This tool updates open-source runtime files; the prepared game changed.')
    with output.open('x', newline='\n') as stream:
        stream.writelines(f'{value}  {name}\n' for name, value in updated.items())
    print('Created ' + str(output) + '. Back up manifest.sha256, then replace it with this file.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    refresh(parser.parse_args().root)
