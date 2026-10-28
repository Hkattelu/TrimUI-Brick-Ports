#!/usr/bin/env python3
"""Developer tool: derive a copy-only recipe from owned inputs and verified output.

The generated C header contains paths, hashes and offsets, never game bytes.
The old preparer remains the reference implementation. Players do not run this.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import zlib

FINAL = 'a2700be5d4bdc8c7cd2a9443024af2795b4fd40bc13eede4ce3abef25c876d44'

def sha(data):
    return hashlib.sha256(data).hexdigest()

def movie(data):
    if data[:3] == b'CWS':
        data = b'FWS' + data[3:8] + zlib.decompress(data[8:])
    if data[:3] != b'FWS' or struct.unpack_from('<I', data, 4)[0] != len(data):
        raise ValueError('Invalid purchased SWF')
    return data

def build(report, game, prepared, output):
    records = json.loads(report.read_text(encoding='utf-8-sig'))['sourceInputs']
    inputs, blocks = [], []
    for row in records:
        # Only the relative portion of the private reference report is retained.
        name = row['path'].replace('\\', '/').split('/deepdungeonsofdoom/', 1)[1]
        data = (game / name).read_bytes()
        if sha(data) != row['sha256'].lower():
            raise ValueError('Purchased input mismatch: ' + name)
        swf = name.endswith('.swf')
        inputs.append((name, sha(data), len(data), int(swf)))
        if swf:
            blocks.append(movie(data))
    base = b''.join(blocks)
    target = prepared.read_bytes()
    if sha(target) != FINAL:
        raise ValueError('Reference result mismatch')
    # A sparse index finds long unchanged ranges. Individual changed bytes are
    # also copied from the purchased source, so no bytecode/data is embedded.
    index = {}
    for offset in range(0, len(base) - 31, 16):
        index.setdefault(base[offset:offset + 32], offset)
    byte_offsets = [base.index(bytes([n])) for n in range(256)]
    copies = []
    pos = 0
    while pos < len(target):
        offset = index.get(target[pos:pos + 32]) if pos + 32 <= len(target) else None
        length = 1
        if offset is None:
            offset = byte_offsets[target[pos]]
        else:
            length = 32
            limit = min(len(target) - pos, len(base) - offset)
            while length + 4096 <= limit and target[pos+length:pos+length+4096] == base[offset+length:offset+length+4096]:
                length += 4096
            while length < limit and target[pos+length] == base[offset+length]:
                length += 1
        if copies and copies[-1][0] + copies[-1][1] == offset:
            copies[-1][1] += length
        else:
            copies.append([offset, length])
        pos += length
    if b''.join(base[o:o+n] for o, n in copies) != target:
        raise ValueError('Recipe reconstruction failed')
    text = '/* Generated copy offsets only. See make-recipe.py. No game data. */\n'
    text += '#define RESULT_SHA "' + FINAL + '"\n'
    text += '#define RESULT_BYTES ' + str(len(target)) + 'u\n'
    text += '#define BASE_BYTES ' + str(len(base)) + 'u\n'
    text += 'static const struct input inputs[] = {\n'
    text += ''.join('    {%s, %s, %du, %d},\n' % (json.dumps(p), json.dumps(h), n, s) for p,h,n,s in inputs)
    text += '};\nstatic const struct copy copies[] = {\n'
    text += ''.join('    {%du, %du},\n' % (o,n) for o,n in copies)
    text += '};\n'
    output.write_text(text, encoding='utf-8', newline='\n')
    print(json.dumps({'inputFiles': len(inputs), 'sourceBytes': len(base), 'outputBytes': len(target),
                      'copyInstructions': len(copies), 'recipeBytes': len(text), 'sha256': FINAL}))

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('report', 'game', 'prepared', 'output'):
        p.add_argument('--' + name, type=Path, required=True)
    build(**vars(p.parse_args()))
