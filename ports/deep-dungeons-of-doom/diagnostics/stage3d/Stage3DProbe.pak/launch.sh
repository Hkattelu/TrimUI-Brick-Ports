#!/bin/sh
# Own-code Stage3D fixture through the same native NX Redux Ports handoff.
set -eu
test_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
case "$test_root" in /mnt/SDCARD/.ports/ddd-runtime-test-*) ;; *) exit 2 ;; esac
runner=/mnt/SDCARD/Emus/PORTS.pak/launch.sh
[ -f "$runner" ] && [ -f "$test_root/graphics-probe.sh" ] || exit 2
[ -f "$test_root/stage3d-startup-present.swf" ] || exit 2
export DDD_RUNTIME_ROOT="$test_root"
export DDD_TEST_SWF="$test_root/stage3d-startup-present.swf"
exec sh "$runner" "$test_root/graphics-probe.sh"
