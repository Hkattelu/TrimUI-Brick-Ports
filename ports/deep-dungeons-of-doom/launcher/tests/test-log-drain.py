#!/usr/bin/env python3
"""Compile and exercise only the local, original log helper; no game launch."""
import pathlib
import signal
import subprocess
import tempfile

source = pathlib.Path(__file__).resolve().parents[1] / "ddd-log-drain.c"
with tempfile.TemporaryDirectory(prefix="ddd-log-test-") as directory:
    root = pathlib.Path(directory)
    binary = root / "ddd-log-drain"
    subprocess.run(["cc", "-std=c11", "-O2", "-Wall", "-Wextra", "-Werror",
                    str(source), "-o", str(binary)], check=True)
    data = bytes(range(256)) * 32768
    output = root / "capped.log"
    subprocess.run([str(binary), str(output), "4096"], input=data, check=True, timeout=5)
    assert output.read_bytes() == data[:4096]
    # Refusal to overwrite still drains the entire input without a broken pipe.
    result = subprocess.run([str(binary), str(output), "4096"], input=data, timeout=5)
    assert result.returncode == 1 and output.read_bytes() == data[:4096]
    missing = subprocess.run([str(binary), str(root / "missing" / "log"), "4096"],
                             input=data, timeout=5)
    assert missing.returncode == 1
    link = root / "link.log"
    link.symlink_to(output)
    result = subprocess.run([str(binary), str(link), "4096"], input=data, timeout=5)
    assert result.returncode == 1 and output.read_bytes() == data[:4096]
    # A running, idle consumer can be stopped during launcher cleanup.
    child = subprocess.Popen([str(binary), str(root / "idle.log"), "4096"], stdin=subprocess.PIPE)
    try:
        child.stdin.write(b"ready")
        child.stdin.flush()
        import time
        deadline = time.monotonic() + 2
        while not (root / "idle.log").exists() and time.monotonic() < deadline:
            time.sleep(0.01)
        assert (root / "idle.log").exists()
        child.send_signal(signal.SIGTERM)
        assert child.wait(timeout=2) == 0
    finally:
        if child.poll() is None:
            child.kill()
            child.wait()
        child.stdin.close()
    for invalid in ("0", "-1", "16777217", "junk", "12junk"):
        assert subprocess.run([str(binary), str(root / "invalid"), invalid]).returncode == 2
print("PASS: cap, full drain, overwrite/symlink refusal, failed sink, idle cleanup, limits")
