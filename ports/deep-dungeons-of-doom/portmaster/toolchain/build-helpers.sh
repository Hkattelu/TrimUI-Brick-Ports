#!/bin/bash
set -euo pipefail
: "${DDD_PM_HELPERS:?Supply a new private output directory}"
: "${DDD_PM_WESTON:?Supply the extracted WestonPack directory}"
scripts=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
source_root=$(CDPATH='' cd -- "$scripts/../.." && pwd -P)
[ ! -e "$DDD_PM_HELPERS" ]
mkdir -p "$DDD_PM_HELPERS"
sh "$scripts/cross-link.sh" -isystem "$DDD_PM_SYSROOT/usr/include" -O2 -std=c11 -Wall -Wextra -Werror \
  "$source_root/launcher/ddd-log-drain.c" -o "$DDD_PM_HELPERS/ddd-log-drain"
sh "$scripts/cross-link.sh" -isystem "$DDD_PM_SYSROOT/usr/include" -O2 -shared -fPIC -Wall -Wextra -Werror \
  "$source_root/diagnostics/brick/alsa-poll-recovery.c" -ldl -pthread \
  -o "$DDD_PM_HELPERS/libddd_alsa_poll_recovery.so"
sh "$scripts/cross-link.sh" -isystem "$DDD_PM_SYSROOT/usr/include" -O2 -shared -fPIC -Wall -Wextra -Werror \
  "$source_root/diagnostics/brick/egl-shutdown.c" \
  -L"$DDD_PM_WESTON/lib_aarch64/graphics/crusty_x11egl" -Wl,--no-as-needed -lcrusty \
  -Wl,-soname,libCRU.so -o "$DDD_PM_HELPERS/libCRU.so"
