#!/bin/bash
set -euo pipefail
: "${DDD_PM_SYSROOT:?Supply the verified Focal ARM64 sysroot}"
: "${DDD_PM_TOOLCHAIN:?Supply the AArch64 GNU toolchain directory}"
: "${DDD_PM_ALSA_SOURCE:?Supply the collected alsa-lib 1.2.11-1ubuntu0.3 source directory}"
: "${DDD_PM_ALSA_WORK:?Supply a new private build directory}"
scripts=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
[ ! -e "$DDD_PM_ALSA_WORK" ]
cd "$DDD_PM_ALSA_SOURCE"
printf '%s\n' \
  '9f3f2f69b995f9ad37359072fbc69a3a88bfba081fc83e9be30e14662795bb4d  alsa-lib_1.2.11.orig.tar.bz2' \
  'a304e5ac97abb30d1b6020bd4cffa324aeae7451ea4e37b58a6730799c849e66  alsa-lib_1.2.11-1ubuntu0.3.debian.tar.xz' | sha256sum -c -
mkdir -p "$DDD_PM_ALSA_WORK"
tar -xjf alsa-lib_1.2.11.orig.tar.bz2 -C "$DDD_PM_ALSA_WORK"
tar -xJf alsa-lib_1.2.11-1ubuntu0.3.debian.tar.xz -C "$DDD_PM_ALSA_WORK/alsa-lib-1.2.11"
cd "$DDD_PM_ALSA_WORK/alsa-lib-1.2.11"
while read -r patch_name; do
  case "$patch_name" in ''|'#'*) continue ;; esac
  patch -p1 < "debian/patches/$patch_name"
done < debian/patches/series
cp "$scripts/cross-link.sh" "$DDD_PM_ALSA_WORK/cross-link.sh"
chmod 700 "$DDD_PM_ALSA_WORK/cross-link.sh"
CC="$DDD_PM_ALSA_WORK/cross-link.sh" CFLAGS="-O2 -isystem $DDD_PM_SYSROOT/usr/include" \
  AR="$DDD_PM_TOOLCHAIN/bin/aarch64-none-linux-gnu-ar" \
  RANLIB="$DDD_PM_TOOLCHAIN/bin/aarch64-none-linux-gnu-ranlib" \
  ./configure --host=aarch64-linux-gnu --prefix=/usr --libdir=/usr/lib/aarch64-linux-gnu \
  --disable-static --disable-python --disable-topology \
  --with-configdir=/usr/share/alsa --with-plugindir=/usr/lib/alsa-lib
make -j2
make DESTDIR="$DDD_PM_ALSA_WORK/install" install
