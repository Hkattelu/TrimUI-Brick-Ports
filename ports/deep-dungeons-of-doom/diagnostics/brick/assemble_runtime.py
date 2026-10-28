"""Assemble verified Debian package payloads for one private ARM64 runtime.

Run through the existing WSL Python. No maintainer scripts execute, and no
system paths are written. Libraries become regular files so FAT/exFAT devices
do not need symlink support. This does not validate the target GPU or audio.
"""
import ctypes
import argparse
import hashlib
import io
import json
import lzma
import os
from pathlib import Path, PurePosixPath
import posixpath
import shutil
import tarfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--root", required=True, type=Path, help="Private output from Prepare-Libraries.ps1")
args = parser.parse_args()
ROOT = args.root.resolve()
DEST = ROOT / "portable"
DEST.mkdir(exist_ok=False)
(DEST / "lib").mkdir(exist_ok=True)
records = json.loads((ROOT / "packages.json").read_text(encoding="utf-8-sig"))
libzstd = ctypes.CDLL("libzstd.so.1")
libzstd.ZSTD_getFrameContentSize.argtypes = [ctypes.c_void_p, ctypes.c_size_t]
libzstd.ZSTD_getFrameContentSize.restype = ctypes.c_uint64
libzstd.ZSTD_decompress.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t]
libzstd.ZSTD_decompress.restype = ctypes.c_size_t
libzstd.ZSTD_isError.argtypes = [ctypes.c_size_t]
libzstd.ZSTD_isError.restype = ctypes.c_uint

def payload(path):
    data = path.read_bytes()
    if path.suffix == ".zst":
        size = libzstd.ZSTD_getFrameContentSize(data, len(data))
        if size >= 2**64 - 2:
            size = 128 * 1024 * 1024
        if size > 128 * 1024 * 1024:
            raise ValueError("Unexpectedly large package payload")
        out = ctypes.create_string_buffer(size)
        count = libzstd.ZSTD_decompress(out, size, data, len(data))
        if libzstd.ZSTD_isError(count):
            raise ValueError("Zstd decompression failed")
        return out.raw[:count]
    if path.suffix == ".xz":
        return lzma.decompress(data)
    raise ValueError("Unsupported data compression: " + str(path))

def clean(value):
    result = posixpath.normpath(value).lstrip("/")
    if result == ".." or result.startswith("../"):
        raise ValueError("Unsafe archive path")
    return result

manifest = []
for record in records:
    archive = (ROOT / record["dataArchive"]).resolve()
    if ROOT not in archive.parents:
        raise ValueError("Payload must remain within the private output directory")
    with tarfile.open(fileobj=io.BytesIO(payload(archive)), mode="r:") as tar:
        members = {clean(member.name): member for member in tar.getmembers()}
        def content(member, visited=None):
            visited = set() if visited is None else visited
            if member.name in visited:
                raise ValueError("Cyclic package link")
            visited.add(member.name)
            if member.issym() or member.islnk():
                if member.linkname.startswith("/") or member.islnk():
                    name = clean(member.linkname)
                else:
                    name = clean(posixpath.join(posixpath.dirname(member.name), member.linkname))
                if name not in members:
                    raise ValueError("Unresolved package link: " + name)
                return content(members[name], visited)
            if not member.isfile():
                raise ValueError("Expected regular package payload")
            return tar.extractfile(member).read()
        for name, member in members.items():
            if member.isdir():
                continue
            base = PurePosixPath(name).name
            # Direct/runtime-dlopen libraries. Driver and EGL libraries remain
            # firmware-owned; this bundle deliberately does not include Mesa.
            library = (name.startswith("usr/lib/aarch64-linux-gnu/") or name.startswith("lib/aarch64-linux-gnu/")) and "/gconv/" not in name and "/ossl-modules/" not in name and (".so" in base)
            license_file = name.startswith("usr/share/doc/") and base in ("copyright", "copyright.gz")
            data_file = name.startswith(("usr/share/alsa/", "usr/share/X11/xkb/"))
            if not (library or license_file or data_file):
                continue
            target = DEST / ("lib/" + base if library else name)
            value = content(member)
            digest = hashlib.sha256(value).hexdigest()
            if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() != digest:
                raise ValueError("Conflicting package path: " + str(target))
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(value)
            if library:
                os.chmod(target, 0o755)
            manifest.append({"file":str(target.relative_to(DEST)),"package":record["package"],"source_member":name,"bytes":len(value),"sha256":digest})

shutil.copyfile(ROOT / "packages.json", DEST / "packages.json")
(DEST / "files.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
with tarfile.open(ROOT / "portable-arm64-libraries.tar.gz", mode="w:gz") as bundle:
    bundle.add(DEST, arcname="portable")
print(json.dumps({"files":len(manifest),"bytes":sum(x["bytes"] for x in manifest),"archive":str(ROOT / "portable-arm64-libraries.tar.gz")}, indent=2))
