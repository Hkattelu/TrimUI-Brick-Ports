#!/usr/bin/env python3
"""Collect exact cached dependency notices; does not build or contact a device."""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

SOURCE_COMMIT = 'ddb9a7c16792378837d95d62ee69927015882c6f'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def collect(metadata_path, source, portable, output, supplement=None, weston_egl=None):
    source = source.resolve(strict=True)
    if subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip() != SOURCE_COMMIT:
        raise ValueError('Use the accepted Ruffle source checkpoint.')
    if subprocess.check_output(['git', '-C', str(source), 'status', '--porcelain']):
        raise ValueError('The Ruffle source must be clean.')
    metadata = json.loads(metadata_path.read_text())
    packages = {p['id']: p for p in metadata['packages']}
    nodes = {p['id']: p for p in metadata['resolve']['nodes']}
    roots = [p['id'] for p in packages.values() if p['name'] == 'ruffle_desktop']
    if len(roots) != 1:
        raise ValueError('Expected one Ruffle desktop root.')
    reached, pending = set(), list(roots)
    while pending:
        key = pending.pop()
        if key in reached:
            continue
        reached.add(key)
        for dep in nodes[key]['deps']:
            if any(kind['kind'] != 'dev' for kind in dep['dep_kinds']):
                pending.append(dep['pkg'])
    output.mkdir(parents=False, exist_ok=False)
    copied = []
    copied_paths = {}

    def copy(path, relative):
        if relative in copied_paths:
            if digest(path) != copied_paths[relative]:
                raise ValueError('Conflicting notice names: ' + relative)
            return
        target = output / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)
        copied.append({'path': relative, 'sha256': digest(target)})
        copied_paths[relative] = digest(target)

    copy(source / 'LICENSE.md', 'Ruffle-LICENSE.md')
    supplements = []
    if supplement:
        supplements = json.loads((supplement / 'supplement.json').read_text(encoding='utf-8-sig'))
        for row in supplements:
            path = supplement / row['file']
            if not path.resolve().is_relative_to(supplement.resolve()) or digest(path) != row['sha256']:
                raise ValueError('Invalid supplemental notice: ' + row['file'])
    rows, missing, review_notes = [], [], []
    for key in sorted(reached):
        package = packages[key]
        root = Path(package['manifest_path']).parent
        notices = []
        # Include nested vendor notices as well as the crate's top-level license.
        for path in root.rglob('*'):
            if path.is_file() and not path.is_symlink() and (re.search(r'(?i)(licen[cs]e|copying|copyright|notice)', path.name) or path.name in ('OFL.txt', 'UFL.txt', 'Hack-Regular.txt')):
                if not any(part in ('.git', 'target') for part in path.relative_to(root).parts):
                    notices.append(path)
        # Git dependencies commonly keep the license above the crate directory.
        if (package.get('source') or '').startswith('git+'):
            ancestors = [root, *root.parents]
            git_root = next((p for p in ancestors if (p / '.git').exists()), None)
            if git_root is None:
                raise ValueError('Could not locate the cached Git dependency root.')
            for parent in ancestors[1:ancestors.index(git_root) + 1]:
                notices.extend(p for p in parent.iterdir() if p.is_file() and not p.is_symlink()
                               and re.match(r'(?i)^(licen[cs]e|copying|copyright|notice)(?:[._-]|$)', p.name))
        if package.get('license_file'):
            explicit = (root / package['license_file']).resolve(strict=True)
            if explicit not in notices:
                notices.append(explicit)
        reference = package.get('source')
        if reference is None:
            reference = 'ruffle-source/' + root.relative_to(source).as_posix() + '@' + SOURCE_COMMIT
        folder = re.sub('[^a-zA-Z0-9_.+-]', '_', package['name'] + '-' + package['version'])
        folder += '-' + hashlib.sha256(reference.encode()).hexdigest()[:8]
        listed = []
        origins = []
        primary = False
        for path in sorted(set(notices)):
            filename = hashlib.sha256(os.path.relpath(path, root).encode()).hexdigest()[:10]
            filename += '-' + re.sub('[^a-zA-Z0-9_.+-]', '_', path.name)
            relative = 'rust/' + folder + '/' + filename
            copy(path, relative)
            listed.append(relative)
            origin = os.path.relpath(path, root)
            origins.append({'notice': relative, 'packageRelativeSource': origin})
            if path.parent == root or path.parent in root.parents or path.parent.name.lower() in ('licenses', 'licences') or package.get('license_file'):
                primary = True
        for extra in supplements:
            if package['name'] + '@' + package['version'] in extra['crates']:
                relative = 'upstream/' + extra['file']
                if relative not in {row['path'] for row in copied}:
                    copy(supplement / extra['file'], relative)
                listed.append(relative)
                origins.append({'notice': relative, 'url': extra['url']})
                if '/fonts/' not in extra['url']:
                    primary = True
        if not primary and package.get('source') is None:
            listed.append('Ruffle-LICENSE.md')
            primary = True
        if not primary:
            missing.append(package['name'] + '@' + package['version'])
            if package['name'] == 'realfft' and package['version'] == '3.5.0':
                declaration = root / 'README.md'
                if 'License: MIT' not in declaration.read_text():
                    raise ValueError('RealFFT license declaration changed.')
                relative = 'declarations/realfft-3.5.0-README.md'
                copy(declaration, relative)
                review_notes.append({'package': 'realfft@3.5.0', 'declaration': relative,
                                     'note': 'Cargo metadata and upstream README declare MIT, but this version includes no standalone copyright/license notice. The exact source crate is retained for release review.'})
        rows.append({'name': package['name'], 'version': package['version'],
                     'license': package['license'], 'source': reference,
                     'notices': listed, 'noticeOrigins': origins,
                     'primaryNoticeIdentified': primary})
    locks = json.loads((Path(__file__).resolve().parent.parent / 'diagnostics/brick/packages.lock.json').read_text())
    native = []
    for package in locks:
        name = package['package']
        base = portable / 'usr/share/doc' / name
        found = [p for p in base.glob('copyright*') if p.is_file() and not p.is_symlink()]
        if not found:
            missing.append('Debian:' + name)
        for path in found:
            copy(path, 'debian/' + name + '/' + path.name)
        # Ubuntu ships libgcc-s1's copyright through gcc-14-base's doc link.
        if not found and name == 'libgcc-s1' and (portable / 'usr/share/doc/gcc-14-base/copyright').is_file():
            copy(portable / 'usr/share/doc/gcc-14-base/copyright', 'debian/libgcc-s1/copyright')
            missing.remove('Debian:' + name)
        native.append(package)
    if weston_egl:
        egl = json.loads((weston_egl / 'egl-provenance.json').read_text())
        copyright_row = next(row for row in egl['extracted'] if row['file'] == 'copyright')
        if digest(weston_egl / 'copyright') != copyright_row['sha256']:
            raise ValueError('EGL notice checksum mismatch.')
        copy(weston_egl / 'copyright', 'debian/libegl1/copyright')
        native.append({'package': 'libegl1', 'version': egl['version'], 'sourcePackage': egl['sourcePackage'],
                       'sha256': egl['binary']['sha256'], 'url': egl['binary']['url']})
    # Debian copyright files refer to these canonical complete license texts.
    for name in ['Apache-2.0', 'BSD', 'CC0-1.0', 'GPL-2', 'GPL-3', 'LGPL-2', 'LGPL-2.1', 'LGPL-3']:
        path = Path(__file__).resolve().parent / 'common-licenses' / name
        if path.is_file():
            copy(path, 'common-licenses/' + name)
        else:
            missing.append('common-license:' + name)
    result = {'schema': 1, 'sourceCommit': SOURCE_COMMIT,
              'scope': 'Conservative normal/build dependency closure from Cargo metadata for aarch64; includes build tools and may include workspace feature unions.',
              'rust': sorted(rows, key=lambda x: (x['name'], x['version'])), 'native': native,
              'files': sorted(copied, key=lambda x: x['path']), 'missingNotices': missing,
              'reviewNotes': review_notes,
              'supplementalSources': [{k:v for k,v in row.items() if k != 'crates'} for row in supplements],
              'redistributionReviewComplete': False,
              'remaining': ['Review license choices and source availability against the actual distributed binaries.']}
    (output / 'inventory.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'rustPackages': len(rows), 'nativePackages': len(native),
                      'noticeFiles': len(copied), 'missing': missing,
                      'licenseExpressions': dict(Counter(r['license'] for r in rows))}, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--metadata', type=Path, required=True)
    parser.add_argument('--ruffle-source', type=Path, required=True)
    parser.add_argument('--portable', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--supplement', type=Path)
    parser.add_argument('--weston-egl', type=Path)
    args = parser.parse_args()
    collect(args.metadata, args.ruffle_source, args.portable, args.output, args.supplement, args.weston_egl)
