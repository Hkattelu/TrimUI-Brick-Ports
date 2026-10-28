#!/bin/sh
set -eu
: "${DDD_PM_SYSROOT:?Supply the verified target sysroot}"
: "${DDD_PM_TOOLCHAIN:?Supply the AArch64 GNU toolchain directory}"
exec "$DDD_PM_TOOLCHAIN/bin/aarch64-none-linux-gnu-g++" \
    --sysroot="$DDD_PM_SYSROOT" -isystem "$DDD_PM_SYSROOT/usr/include/aarch64-linux-gnu" \
    -B"$DDD_PM_SYSROOT/usr/lib/aarch64-linux-gnu/" -L"$DDD_PM_SYSROOT/usr/local/lib" \
    -Wl,-rpath-link,"$DDD_PM_SYSROOT/usr/local/lib" -L"$DDD_PM_SYSROOT/usr/lib/aarch64-linux-gnu" \
    -Wl,-rpath-link,"$DDD_PM_SYSROOT/usr/lib/aarch64-linux-gnu" "$@"
