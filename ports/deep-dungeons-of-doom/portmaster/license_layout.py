"""Flatten a verified notice collection into one text file per component."""
import hashlib
from collections import Counter
from pathlib import PurePosixPath
import re


def assemble(inventory, notice_files):
    if inventory['missingNotices']:
        raise ValueError('Resolve missing notices before packaging.')
    groups = {'Ruffle': ['Ruffle-LICENSE.md']}
    identities = Counter((package['name'], package['version']) for package in inventory['rust'])
    for package in inventory['rust']:
        component = package['name'] + '-' + package['version']
        if identities[(package['name'], package['version'])] > 1:
            component += '-' + hashlib.sha256(package['source'].encode()).hexdigest()[:8]
        if component in groups:
            raise ValueError('Duplicate component: ' + component)
        groups[component] = package['notices']
    for package in inventory['native']:
        component = package['package'] + '-' + package['version']
        prefix = 'debian/' + package['package'] + '/'
        if component in groups:
            raise ValueError('Duplicate component: ' + component)
        groups[component] = [name for name in notice_files if name.startswith(prefix)]
    referenced = {name for names in groups.values() for name in names}
    for name in sorted(set(notice_files) - referenced):
        # Canonical license texts and supplemental declarations also remain flat.
        component = name.replace('/', '-')
        if component in groups:
            raise ValueError('Duplicate supplemental notice: ' + name)
        groups[component] = [name]

    entries, records = {}, []
    for component, names in sorted(groups.items()):
        filename = 'LICENSE.' + re.sub(r'[^A-Za-z0-9_.+-]', '_', component) + '.txt'
        if filename.casefold() in {name.casefold() for name in entries}:
            raise ValueError('Colliding flat license filename: ' + filename)
        if not names:
            raise ValueError('Component has no notices: ' + component)
        data = bytearray()
        sections = []
        for name in sorted(set(names)):
            if name not in notice_files or '..' in PurePosixPath(name).parts:
                raise ValueError('Unverified notice: ' + name)
            original = notice_files[name].read_bytes()
            data.extend(('Source notice: ' + name + '\n\n').encode())
            offset = len(data)
            data.extend(original)
            data.extend(b'\n\n')
            sections.append({'source': name, 'offset': offset, 'bytes': len(original),
                             'sha256': hashlib.sha256(original).hexdigest()})
        entries[filename] = bytes(data)
        records.append({'path': filename, 'component': component,
                        'sha256': hashlib.sha256(data).hexdigest(), 'sections': sections})
    return entries, {'schema': 1, 'sourceCommit': inventory['sourceCommit'],
                     'scope': inventory['scope'], 'files': records,
                     'redistributionReviewComplete': inventory['redistributionReviewComplete'],
                     'remaining': inventory['remaining']}
