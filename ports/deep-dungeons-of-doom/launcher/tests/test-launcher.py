#!/usr/bin/env python3
"""Local Linux checks. Never mount Weston, access evdev, or launch the game."""
import hashlib
import os
import pathlib
import signal
import subprocess
import tempfile

source = pathlib.Path(__file__).resolve().parents[1]
common = source / "launcher-common.sh"
for script in source.glob("*.sh"):
    assert b"\r" not in script.read_bytes(), script
    subprocess.run(["sh", "-n", str(script)], check=True)

with tempfile.TemporaryDirectory(prefix="ddd-launch-test-") as directory:
    temp = pathlib.Path(directory)
    installed = temp / "installed"
    scratch = temp / "checks"
    installed.mkdir()
    scratch.mkdir()
    required = ["launch.sh", "run-game.sh", "launcher-common.sh", "ddd-log-drain",
                "ddd-exit-watch", "ruffle", "ddd.swf", "libddd_alsa_poll_recovery.so",
                "portable/lib/ld-linux-aarch64.so.1", "portable/lib/libc.so.6"]
    for name in required:
        path = installed / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("fixture: " + name)
        path.chmod(0o700)
    manifest = installed / "manifest.sha256"
    def write_manifest(names=required):
        manifest.write_text("".join(hashlib.sha256((installed / name).read_bytes()).hexdigest()
                                    + "  " + name + "\n" for name in names))
    def validate(expected):
        result = subprocess.run(["sh", "-c", '. "$1"; ddd_validate_manifest "$2" "$3"',
                                 "test", str(common), str(installed), str(scratch)],
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        assert (result.returncode == 0) == expected, result.stderr.decode()
    write_manifest()
    good = manifest.read_text()
    validate(True)
    # Ordinary saves and logs deliberately remain outside the immutable manifest.
    (installed / "profile").mkdir()
    (installed / "profile/save.sol").write_text("save")
    validate(True)
    manifest.write_text(good + good.splitlines()[0] + "\n")
    validate(False)
    manifest.write_text("\n".join(good.splitlines()[:-1]) + "\n")
    validate(False)
    manifest.write_text(good.replace("ddd.swf", "../ddd.swf"))
    validate(False)
    manifest.write_text(good.replace("ddd.swf", "/tmp/ddd.swf"))
    validate(False)
    manifest.write_text(good.replace("ddd.swf", "portable/./ddd.swf"))
    validate(False)
    manifest.write_text(good.replace("ddd.swf", "profile/save.sol"))
    validate(False)
    manifest.write_text(good + "$(touch injected)\n")
    validate(False)
    assert not (installed / "injected").exists()
    manifest.write_text(good)
    (installed / "ruffle").write_text("changed runtime")
    validate(False)
    (installed / "ruffle").write_text("fixture: ruffle")
    outside = temp / "outside"
    outside.write_text("outside")
    (installed / "portable/lib/libc.so.6").unlink()
    (installed / "portable/lib/libc.so.6").symlink_to(outside)
    write_manifest()
    validate(False)
    (installed / "portable/lib/libc.so.6").unlink()
    (installed / "portable/lib/libc.so.6").write_text("fixture: portable/lib/libc.so.6")
    (installed / "portable/lib/extra.so").write_text("unlisted dependency")
    write_manifest()
    validate(False)
    (installed / "portable/lib/extra.so").unlink()
    # Internal library symlinks are allowed only when included in the closure.
    (installed / "portable/lib/libc-link.so").symlink_to("libc.so.6")
    write_manifest(required + ["portable/lib/libc-link.so"])
    validate(True)
    os.mkfifo(installed / "portable/lib/unlisted.pipe")
    validate(False)
    (installed / "portable/lib/unlisted.pipe").unlink()
    (temp / "empty-outside").mkdir()
    (installed / "portable/lib/escape").symlink_to(temp / "empty-outside", target_is_directory=True)
    validate(False)

    ownership = temp / "ownership.sh"
    ownership.write_text(r'''#!/bin/sh
set -eu
. "$1"
folder=$2
own= token= tree= tree_token= named= named_token=
cleanup() {
    ddd_stop "$own" "$token"
    ddd_stop "$named" "$named_token"
    if [ -f "$folder/descendants" ]; then
        while read -r pid start ppid; do ddd_stop "$pid" "$start"; done < "$folder/descendants"
    fi
    ddd_stop "$tree" "$tree_token"
}
trap cleanup EXIT INT TERM
sleep 30 &
own=$!
token=$(ddd_child_token "$own" "$$")
ddd_live "$own" "$token"
if ddd_child_token "$own" 1; then exit 1; fi
ddd_stop "$own" invalid-token
ddd_live "$own" "$token"
ddd_stop "$own" "$token"
if ddd_live "$own" "$token"; then exit 1; fi
wait "$own" 2>/dev/null || true
own=
python3 -c 'import ctypes,time; ctypes.CDLL(None).prctl(15,b"ddd ) name",0,0,0); time.sleep(30)' &
named=$!
named_token=$(ddd_child_token "$named" "$$")
sleep 0.1
ddd_live "$named" "$named_token"
[ "$(ddd_process_info "$named" | cut -d ' ' -f 1)" = "$$" ]
sh -c 'sleep 30 & wait' &
tree=$!
tree_token=$(ddd_child_token "$tree" "$$")
sleep 0.1
ddd_remember_descendants "$tree" invalid-token "$folder/rejected"
[ ! -e "$folder/rejected" ]
ddd_remember_descendants "$tree" "$tree_token" "$folder/descendants"
[ "$(wc -l < "$folder/descendants")" = 1 ]
while read -r pid start ppid; do
    [ "$ppid" = "$tree" ]
    [ "$(ddd_child_token "$pid" "$tree")" = "$start" ]
done < "$folder/descendants"
mkfifo "$folder/owned.pipe"
identity=$(ddd_identity "$folder/owned.pipe")
mv "$folder/owned.pipe" "$folder/old.pipe"
mkfifo "$folder/owned.pipe"
ddd_remove "$folder/owned.pipe" "$identity"
[ -p "$folder/owned.pipe" ]
ddd_remove "$folder/old.pipe" "$identity"
[ ! -e "$folder/old.pipe" ]
mkdir "$folder/owned.directory"
identity=$(ddd_identity "$folder/owned.directory")
mv "$folder/owned.directory" "$folder/old.directory"
mkdir "$folder/owned.directory"
ddd_remove "$folder/owned.directory" "$identity"
[ -d "$folder/owned.directory" ]
ddd_remove "$folder/old.directory" "$identity"
[ ! -e "$folder/old.directory" ]
''')
    child = subprocess.Popen(["sh", str(ownership), str(common), str(temp)], start_new_session=True)
    try:
        assert child.wait(timeout=15) == 0
    finally:
        # This session contains only disposable processes created by this test.
        try:
            os.killpg(child.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        if child.poll() is None:
            child.wait(timeout=5)

print("PASS: shell syntax/LF, manifest closure and refusals, real process ownership, replaced FIFO/directory retention")
