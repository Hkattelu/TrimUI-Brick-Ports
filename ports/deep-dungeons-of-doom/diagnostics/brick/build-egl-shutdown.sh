#!/bin/sh
set -eu
# CC may be an existing cross-compiler wrapper; no compiler is downloaded here.
: "${CC:?Set CC to an ARM64 C compiler or compiler wrapper}"
: "${CRUSTY_DIRECTORY:?Set the directory of the extracted Crusty X11/EGL shim}"
: "${OUT_DIR:?Set a new output directory}"
source_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
expected=eceaa845d6754c11f0ba5159f8a54efe4ee181e9a770088bae72d12ea83c531d
[ "$(sha256sum "$CRUSTY_DIRECTORY/libcrusty.so" | cut -d ' ' -f 1)" = "$expected" ] || {
    printf '%s\n' 'Unsupported Crusty library; do not apply the termination workaround.' >&2
    exit 2
}
mkdir "$OUT_DIR"
"$CC" -shared -fPIC -O2 -Wall -Wextra -Werror -nostdlib \
    -Wl,-soname,libCRU.so -Wl,--no-as-needed -L"$CRUSTY_DIRECTORY" \
    "$source_dir/egl-shutdown.c" -l:libcrusty.so -o "$OUT_DIR/libCRU.so"
sha256sum "$OUT_DIR/libCRU.so"
