#!/usr/bin/env python3
"""Record the complete accepted Ruffle diff and exact copyleft/font crate sources."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

COMMIT = 'ddb9a7c16792378837d95d62ee69927015882c6f'
UPSTREAM = '159d7dbbca40bd475c8693df011b3dbf66213844'
TREE = 'c4deba3cdc60e4889f9e14539652c2b2fdd90490'
FLASH_COMMIT = '61b717248aae853a4f5d8a103eba704268d286c8'
VENDOR = 'core/vendor/flash-lso/'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def collect(source, cargo_home, inventory_file, output):
    def git(*args):
        return subprocess.check_output(['git', '-C', str(source), *args])
    if git('rev-parse', 'HEAD').decode().strip() != COMMIT or git('status', '--porcelain'):
        raise ValueError('Expected the clean accepted Ruffle source checkpoint.')
    if git('rev-parse', 'HEAD^{tree}').decode().strip() != TREE:
        raise ValueError('Unexpected source tree identity.')
    changed = git('diff', '--name-only', UPSTREAM, COMMIT).decode().splitlines()
    # The vendored dependency includes public AMF test fixtures. Allow only
    # byte-identical blobs from its pinned upstream commit, never private saves.
    caches = list((cargo_home / 'git/checkouts').glob('rust-flash-lso-*/61b7172'))
    if len(caches) != 1:
        raise ValueError('Expected the exact pinned flash-lso source cache.')
    cache = caches[0]
    if subprocess.check_output(['git', '-C', str(cache), 'rev-parse', 'HEAD']).decode().strip() != FLASH_COMMIT:
        raise ValueError('Unexpected flash-lso upstream commit.')
    patched = {'src/amf3/write.rs', 'src/amf3/element_cache.rs', 'LICENSE',
               'DDD-PATCH.md', 'tests/ddd_inline_references.rs'}
    verified_vendor = {}
    normalized_text = []
    for path in changed:
        if not path.startswith(VENDOR) or path[len(VENDOR):] in patched:
            continue
        original = subprocess.check_output(['git', '-C', str(cache), 'show', FLASH_COMMIT + ':flash-lso/' + path[len(VENDOR):]])
        current = git('show', COMMIT + ':' + path)
        if original != current and path.endswith('.rs') and original.replace(b'\r\n', b'\n') == current:
            normalized_text.append(path)
        elif original != current:
            raise ValueError('Unexpected vendor modification: ' + path)
        verified_vendor[path] = hashlib.sha256(current).hexdigest()
    if len(verified_vendor) != 209:
        raise ValueError('Unexpected upstream vendor file set.')
    if any(p.lower().endswith(('.swf', '.sol', '.dll', '.ane', '.exe')) and p not in verified_vendor for p in changed):
        raise ValueError('Unexpected binary/game content in source changes.')
    binary_paths = [line.split('\t', 2)[2] for line in git('diff', '--numstat', '--no-renames', UPSTREAM, COMMIT).decode().splitlines() if line.startswith('-\t-\t')]
    if any(path not in verified_vendor for path in binary_paths):
        raise ValueError('Binary source changes are not verified upstream fixtures.')
    patch = git('diff', '--binary', '--full-index', '--no-renames', UPSTREAM, COMMIT)
    output.mkdir(exist_ok=False)
    patch_file = output / 'ruffle-ddd-complete.patch'
    patch_file.write_bytes(patch)
    # Check the complete clean index; a sparse checkout may omit test fixtures
    # physically while still containing their accepted committed objects.
    subprocess.run(['git', '-C', str(source), 'apply', '--cached', '--reverse', '--check', str(patch_file.resolve())], check=True)
    shutil.copyfile(source / 'LICENSE.md', output / 'Ruffle-LICENSE.md')
    shutil.copyfile(source / 'Cargo.lock', output / 'Cargo.lock')
    # Cargo.lock is generated data. Read only scalar package identity/checksum
    # fields; no source configuration or build script is executed here.
    checksums = {}
    for block in (source / 'Cargo.lock').read_text().split('[[package]]')[1:]:
        values = {}
        for key, value in re.findall(r'(?m)^(name|version|source|checksum) = ("[^"\n]*")$', block):
            values[key] = json.loads(value)
        if 'checksum' in values:
            checksums[(values['name'], values['version'])] = values['checksum']
    inventory = json.loads(inventory_file.read_text())
    required = [r for r in inventory['rust'] if 'MPL' in (r['license'] or '') or r['name'] in ('epaint_default_fonts', 'realfft')]
    archives = []
    for row in required:
        name = row['name'] + '-' + row['version'] + '.crate'
        matches = list((cargo_home / 'registry/cache').glob('*/' + name))
        if len(matches) != 1 or sha(matches[0]) != checksums[(row['name'], row['version'])]:
            raise ValueError('Missing or incorrect cached crate: ' + name)
        target = output / 'crates' / name
        target.parent.mkdir(exist_ok=True)
        shutil.copyfile(matches[0], target)
        archives.append({'file': 'crates/' + name, 'sha256': sha(target),
                         'url': 'https://static.crates.io/crates/' + row['name'] + '/' + name,
                         'license': row['license'], 'unmodified': True})
    report = {'schema': 1, 'upstreamCommit': UPSTREAM, 'sourceCommit': COMMIT, 'sourceTree': TREE,
              'patch': patch_file.name, 'patchSha256': sha(patch_file), 'changedFiles': changed,
              'reverseApplyCheckPassed': True, 'cargoLockSha256': sha(output / 'Cargo.lock'),
              'vendoredFlashLso': {'upstreamCommit': FLASH_COMMIT, 'verifiedUnmodifiedFiles': verified_vendor,
                                  'crlfNormalizedRustFiles': normalized_text,
                                  'locallyChangedOrAdded': sorted(patched), 'verifiedBinaryFixtures': binary_paths},
              'crateSources': archives, 'gameIncluded': False, 'cleanRebuildPerformed': False, 'published': False}
    (output / 'source-provenance.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'sourceCommit': COMMIT, 'patchBytes': len(patch), 'changedFiles': len(changed),
                      'verifiedCrateSources': len(archives), 'reverseApplyCheckPassed': True}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ruffle-source', type=Path, required=True)
    parser.add_argument('--cargo-home', type=Path, required=True)
    parser.add_argument('--inventory', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    collect(args.ruffle_source, args.cargo_home, args.inventory, args.output)
