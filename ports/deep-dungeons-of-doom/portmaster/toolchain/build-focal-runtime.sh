#!/bin/bash
set -euo pipefail
: "${DDD_PM_SOURCE:?Supply the clean Ruffle source checkout}"
: "${DDD_PM_SYSROOT:?Supply the verified Focal ARM64 sysroot}"
: "${DDD_PM_TOOLCHAIN:?Supply the AArch64 GNU toolchain directory}"
: "${CARGO_TARGET_DIR:?Supply a private build directory}"
cd "$DDD_PM_SOURCE"
[ "$(git rev-parse 'HEAD^{tree}')" = c4deba3cdc60e4889f9e14539652c2b2fdd90490 ]
[ -z "$(git status --porcelain)" ]
scripts=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
wrappers="$CARGO_TARGET_DIR/ddd-toolchain"
mkdir -p "$wrappers"
cp "$scripts/cross-link.sh" "$scripts/cross-cxx.sh" "$wrappers/"
chmod 700 "$wrappers/cross-link.sh" "$wrappers/cross-cxx.sh"
export CARGO_BUILD_JOBS=2
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER="$wrappers/cross-link.sh"
export CC_aarch64_unknown_linux_gnu="$wrappers/cross-link.sh"
export CXX_aarch64_unknown_linux_gnu="$wrappers/cross-cxx.sh"
export AR_aarch64_unknown_linux_gnu="$DDD_PM_TOOLCHAIN/bin/aarch64-none-linux-gnu-ar"
export PKG_CONFIG_ALLOW_CROSS=1 PKG_CONFIG_SYSROOT_DIR="$DDD_PM_SYSROOT"
export PKG_CONFIG_LIBDIR="$DDD_PM_SYSROOT/usr/local/lib/pkgconfig:$DDD_PM_SYSROOT/usr/lib/aarch64-linux-gnu/pkgconfig:$DDD_PM_SYSROOT/usr/lib/pkgconfig:$DDD_PM_SYSROOT/usr/share/pkgconfig"
export PKG_CONFIG_PATH=
export BINDGEN_EXTRA_CLANG_ARGS="--sysroot=$DDD_PM_SYSROOT -isystem $DDD_PM_SYSROOT/usr/include/aarch64-linux-gnu -isystem $DDD_PM_TOOLCHAIN/lib/gcc/aarch64-none-linux-gnu/13.2.1/include"
exec rustup run stable cargo build --locked --offline --profile dist -p ruffle_desktop \
    --features jpegxr,fontconfig-dlopen --target aarch64-unknown-linux-gnu
