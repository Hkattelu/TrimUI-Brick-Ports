#!/usr/bin/env python3
"""Exercise library replacement through the real installation manifest validator."""
import importlib.util
from pathlib import Path
import shutil
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('refresh', HERE / 'refresh-runtime-manifest.py')
refresh = importlib.util.module_from_spec(spec)
spec.loader.exec_module(refresh)


with tempfile.TemporaryDirectory(prefix='ddd-library-replacement-') as temp:
    root = Path(temp) / 'port with spaces'
    root.mkdir()
    for name in refresh.ROOT_FILES:
        (root / name).write_text('original ' + name)
        (root / name).chmod(0o755)
    shutil.copyfile(HERE.parent / 'launcher/launcher-common.sh', root / 'launcher-common.sh')
    (root / 'portable/lib').mkdir(parents=True)
    library = root / 'portable/lib/example.so'
    library.write_bytes(b'original shared library fixture')
    loader = root / 'portable/lib/ld-linux-aarch64.so.1'
    loader.write_bytes(b'loader fixture')
    loader.chmod(0o755)
    names = sorted([*refresh.ROOT_FILES, 'portable/lib/example.so', 'portable/lib/ld-linux-aarch64.so.1'])
    manifest = root / 'manifest.sha256'
    manifest.write_text(''.join(refresh.digest(root / name) + '  ' + name + '\n' for name in names))
    original = manifest.read_bytes()
    (root / 'profile').mkdir()
    save = root / 'profile/progress.sol'
    save.write_bytes(b'private progress must remain unchanged')
    scratch = Path(temp) / 'validator'
    scratch.mkdir()

    def validate():
        return subprocess.run(['sh', '-c', '. "$1/launcher-common.sh"; ddd_validate_manifest "$1" "$2"',
                               'check', str(root), str(scratch)], capture_output=True).returncode

    assert validate() == 0
    library.write_bytes(b'locally modified shared library fixture')
    assert validate() != 0
    (root / 'portable/lib/new-dependency.so').write_bytes(b'new local dependency')
    refresh.refresh(root)
    assert manifest.read_bytes() == original
    modified = root / 'manifest.modified.sha256'
    try:
        refresh.refresh(root)
        raise AssertionError('Overwrote the pending manifest')
    except ValueError:
        pass
    manifest.write_bytes(modified.read_bytes())
    modified.unlink()
    assert validate() == 0
    assert save.read_bytes() == b'private progress must remain unchanged'
    (root / 'ddd.swf').write_bytes(b'changed proprietary game fixture')
    try:
        refresh.refresh(root)
        raise AssertionError('Accepted a changed game')
    except ValueError:
        pass
    assert not modified.exists()
    (root / 'ddd.swf').write_text('original ddd.swf')
    (root / 'portable/escape').symlink_to(Path(temp) / 'outside')
    try:
        refresh.refresh(root)
        raise AssertionError('Accepted a portable symlink')
    except ValueError:
        pass
    assert not modified.exists()
print('Runtime replacement passed: changed library and new dependency accepted after explicit refresh; game, saves and existing output protected.')
