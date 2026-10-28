#!/usr/bin/env python3
"""Exercise the actual game monitor/cleanup with owned local subprocesses only."""
import hashlib
import os
import pathlib
import signal
import subprocess
import tempfile
import time

source = pathlib.Path(__file__).resolve().parents[1]
script = (source / "run-game.sh").read_text()
cleanup = script[script.index("cleanup() {"):script.index("unset WAYLAND_DISPLAY")]
monitor = script[script.index('while ddd_live "$ruffle_pid" "$ruffle_token"; do'):]
# Original pre-fix monitor from local checkpoint 20de9237589c5f9b48eb3e911a8c357f7213a19f.
# Embedded so the negative control also works in a source ZIP without Git history.
# SHA256 of this exact UTF-8 snippet: 1a9b7ffd7390c75704070b9f2c89c40e0d401aac7fb6bd9cc0a9ac956625e7ce
old_monitor = r'''while ddd_live "$ruffle_pid" "$ruffle_token"; do
    ddd_live "$parent_pid" "$parent_token" || exit 5
    if ! ddd_live "$exit_watch_pid" "$exit_watch_token"; then
        # A successful chord also ends the watcher. Let the runtime complete its
        # SIGTERM path, then cleanup any stalled runtime just as on watch failure.
        sleep 0.3
        if ddd_live "$ruffle_pid" "$ruffle_token"; then exit 5; fi
        break
    fi
    ddd_logs_live "$work" || exit 5
    sleep 0.2
done
set +e
wait "$ruffle_pid"
code=$?
set -e
ruffle_pid='' ruffle_token=''
exit "$code"
'''
assert hashlib.sha256(old_monitor.encode()).hexdigest() == '1a9b7ffd7390c75704070b9f2c89c40e0d401aac7fb6bd9cc0a9ac956625e7ce'

runtime_source = r'''
import os, pathlib, signal, sys, time

def terminate(signum, frame):
    # Reproduce EOF before process teardown finishes, then die by real SIGTERM.
    os.close(1)
    os.close(2)
    time.sleep(.6)
    signal.signal(signal.SIGTERM, signal.SIG_DFL)
    os.kill(os.getpid(), signal.SIGTERM)

signal.signal(signal.SIGTERM, terminate)
pathlib.Path(sys.argv[1]).write_text("ready")
while True:
    signal.pause()
'''

setup = r'''
set -eu
. "$1"
run=$2 work=$2
logger=$3 runtime=$4 mode=$5
ruffle_pid='' ruffle_token='' exit_watch_pid='' exit_watch_token=''
'''
start = r'''
parent_pid=$$
parent_token=$(ddd_token "$$")
mkfifo "$work/ruffle.pipe"
printf '%s %s\n' ruffle.pipe "$(ddd_identity "$work/ruffle.pipe")" > "$work/log-pipes.txt"
"$logger" "$run/runtime.log" 4096 < "$work/ruffle.pipe" &
logger_pid=$!
logger_token=$(ddd_child_token "$logger_pid" "$$")
printf '%s %s\n' "$logger_pid" "$logger_token" > "$work/log-processes.txt"
python3 "$runtime" "$run/runtime-ready" > "$work/ruffle.pipe" 2>&1 &
ruffle_pid=$!
ruffle_token=$(ddd_child_token "$ruffle_pid" "$$")
python3 -c 'import time; time.sleep(30)' &
exit_watch_pid=$!
exit_watch_token=$(ddd_child_token "$exit_watch_pid" "$$")
printf '%s %s\n%s %s\n%s %s\n' "$ruffle_pid" "$ruffle_token" "$exit_watch_pid" "$exit_watch_token" "$logger_pid" "$logger_token" > "$run/owned.txt"
ready_count=0
while [ ! -f "$run/runtime-ready" ]; do
    [ "$ready_count" -lt 100 ] || exit 98
    sleep 0.01
    ready_count=$((ready_count + 1))
done
(
    trap - EXIT INT TERM HUP
    sleep 0.1
    case "$mode" in
        logger-exit) kill -TERM "$ruffle_pid" ;;
        watcher-exit) kill -TERM "$ruffle_pid"; kill -TERM "$exit_watch_pid" ;;
        logger-failure) kill -TERM "$logger_pid" ;;
        watcher-failure) kill -TERM "$exit_watch_pid" ;;
        ordinary-exit) kill -KILL "$ruffle_pid" ;;
        *) exit 99 ;;
    esac
) &
'''

def live(pid, expected):
    try:
        fields = pathlib.Path(f"/proc/{pid}/stat").read_text().rsplit(") ", 1)[1].split()
        return fields[19] == expected and fields[0] not in ("Z", "X")
    except FileNotFoundError:
        return False

with tempfile.TemporaryDirectory(prefix="ddd-game-exit-") as directory:
    root = pathlib.Path(directory)
    logger = root / "ddd-log-drain"
    runtime = root / "runtime.py"
    runtime.write_text(runtime_source)
    subprocess.run(["cc", "-std=c11", "-O2", "-Wall", "-Wextra", "-Werror",
                    str(source / "ddd-log-drain.c"), "-o", str(logger)], check=True)
    sentinel = subprocess.Popen(["sleep", "30"])
    try:
        cases = [("old", "logger-exit", 5), ("new", "logger-exit", 143),
                 ("new", "watcher-exit", 143), ("new", "logger-failure", 5),
                 ("new", "watcher-failure", 5), ("new", "ordinary-exit", 137)]
        for version, mode, expected in cases:
            run = root / f"{version}-{mode}"
            run.mkdir()
            fixture = run / "monitor.sh"
            fixture.write_text(setup + cleanup + start + (old_monitor if version == "old" else monitor))
            before = time.monotonic()
            child = subprocess.Popen(["sh", str(fixture), str(source / "launcher-common.sh"),
                                      str(run), str(logger), str(runtime), mode],
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
            try:
                stdout, stderr = child.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                # This session contains only disposable processes from this fixture.
                os.killpg(child.pid, signal.SIGKILL)
                child.communicate()
                raise
            elapsed = time.monotonic() - before
            assert child.returncode == expected, (version, mode, child.returncode, stderr.decode())
            assert (run / "game-result.txt").read_text() == f"exitCode={expected}\n"
            for line in (run / "owned.txt").read_text().splitlines():
                pid, token = line.split()
                assert not live(pid, token), (version, mode, pid, "surviving owned process")
            assert not (run / "ruffle.pipe").exists()
            assert sentinel.poll() is None, "Unrelated sentinel was stopped"
            assert elapsed < 4, (mode, elapsed)
            print(f"PASS {version} {mode}: exit={expected}, owned cleanup, {elapsed:.2f}s")
    finally:
        sentinel.terminate()
        sentinel.wait(timeout=3)
print("PASS: old loop reproduces false5; actual updated loop preserves SIGTERM143/other137 and retains5 for live-runtime monitor failures")
