#!/usr/bin/env python3
"""Verify NX's hidden data layout and preservation of existing preview progress."""
from pathlib import Path
import subprocess
import tempfile

helper = Path(__file__).resolve().parents[1] / 'diagnostics/brick/stage-nx-preview.sh'
with tempfile.TemporaryDirectory(prefix='ddd-nx-layout-') as temporary:
    ports = Path(temporary) / 'ports with spaces'
    game = ports / 'deepdungeonsofdoom'
    save = game / 'profile/progress.sol'
    save.parent.mkdir(parents=True)
    save.write_bytes(b'preserve latest progress')
    (game / 'ruffle').write_bytes(b'runtime fixture')
    def run(success):
        result = subprocess.run(['sh', str(helper), str(ports)], capture_output=True, text=True)
        assert (result.returncode == 0) == success, result
    run(False)  # Refuse a folder that has no matching menu script.
    assert save.read_bytes() == b'preserve latest progress'
    (ports / 'Deep Dungeons of Doom.sh').write_text('#!/bin/bash\n')
    # The NX launcher binds .ports; an ordinary ZIP extraction is invisible there.
    bound = ports / '.ports/deepdungeonsofdoom'
    assert not (bound / 'ruffle').exists()
    run(True)
    assert not game.exists() and (bound / 'ruffle').read_bytes() == b'runtime fixture'
    assert (bound / 'profile/progress.sol').read_bytes() == b'preserve latest progress'
    game.mkdir()
    (game / 'keep').write_bytes(b'new extraction')
    run(False)  # Never replace an already installed profile with a new extraction.
    assert (game / 'keep').read_bytes() == b'new extraction'
    assert (bound / 'profile/progress.sol').read_bytes() == b'preserve latest progress'
print('PASS: NX bind lookup, spaced paths, profile preservation and collision refusal')
