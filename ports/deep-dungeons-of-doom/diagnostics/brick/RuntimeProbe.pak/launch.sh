#!/bin/sh
# Enter through NX Redux's native /tmp/nextui_open request. The standard Ports
# runner then owns menu handoff, input labeling, power handling and CPU restore.
set -eu
test_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
case "$test_root" in /mnt/SDCARD/.ports/ddd-runtime-test-*) ;; *) exit 2 ;; esac
runner=/mnt/SDCARD/Emus/PORTS.pak/launch.sh
[ -f "$runner" ] && [ -f "$test_root/graphics-probe.sh" ] || exit 2
export DDD_RUNTIME_ROOT="$test_root"
exec sh "$runner" "$test_root/graphics-probe.sh"
