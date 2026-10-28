#!/bin/bash
set -euo pipefail
: "${DDD_PM_SYSROOT:?Supply the verified Focal ARM64 sysroot}"
: "${DDD_PM_TOOLCHAIN:?Supply the AArch64 GNU toolchain directory}"
: "${DDD_PM_FREETYPE_CRATE:?Supply the cached freetype-sys 0.23.0 crate}"
: "${DDD_PM_FREETYPE_WORK:?Supply a new private build directory}"
echo "eab537ce43cab850c64b4cdc390ce7e4f47f877485ddc323208e268280c308ae  $DDD_PM_FREETYPE_CRATE" | sha256sum -c -
[ ! -e "$DDD_PM_FREETYPE_WORK" ]
mkdir -p "$DDD_PM_FREETYPE_WORK"
tar -xzf "$DDD_PM_FREETYPE_CRATE" -C "$DDD_PM_FREETYPE_WORK"
scripts=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
cp "$scripts/cross-link.sh" "$DDD_PM_FREETYPE_WORK/cross-link.sh"
chmod 700 "$DDD_PM_FREETYPE_WORK/cross-link.sh"
cmake -S "$DDD_PM_FREETYPE_WORK/freetype-sys-0.23.0/freetype2" \
    -B "$DDD_PM_FREETYPE_WORK/objects" \
    -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_C_COMPILER="$DDD_PM_FREETYPE_WORK/cross-link.sh" \
    -DCMAKE_SYSROOT="$DDD_PM_SYSROOT" -DCMAKE_FIND_ROOT_PATH="$DDD_PM_SYSROOT" \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
    -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DCMAKE_INSTALL_LIBDIR=lib -DFT_REQUIRE_ZLIB=ON -DFT_REQUIRE_PNG=ON \
    -DFT_DISABLE_HARFBUZZ=ON -DFT_DISABLE_BZIP2=ON -DFT_DISABLE_BROTLI=ON
cmake --build "$DDD_PM_FREETYPE_WORK/objects" --parallel 2
DESTDIR="$DDD_PM_SYSROOT" cmake --install "$DDD_PM_FREETYPE_WORK/objects"
