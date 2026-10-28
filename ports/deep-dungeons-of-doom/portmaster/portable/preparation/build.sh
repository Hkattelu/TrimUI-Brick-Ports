#!/bin/bash
set -euo pipefail
# Uses the same verified Focal sysroot and ARM64 compiler as the game runtime.
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
: "${DDD_PREP_OUTPUT:?Specify a new output file}"
[ ! -e "$DDD_PREP_OUTPUT" ]
sh "$here/../../toolchain/cross-link.sh" -isystem "$DDD_PM_SYSROOT/usr/include" \
  -O2 -std=c11 -Wall -Wextra -Werror "$here/ddd-prepare.c" \
  -lcrypto -lz -o "$DDD_PREP_OUTPUT"
