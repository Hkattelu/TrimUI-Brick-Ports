#!/bin/sh
set -eu
ulimit -c 0
: "${DDD_ALSA_TEST_OUTPUT:?Supply a new private test directory}"
src=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)/alsa-poll-recovery.c
out=$DDD_ALSA_TEST_OUTPUT
[ ! -e "$out" ]
mkdir -p "$out/missing"
gcc -std=c11 -O2 -Wall -Wextra -Werror -fPIC -shared -Wl,-z,defs,-z,relro,-z,now \
    -o "$out/libddd_alsa_poll_recovery.so" "$src" -ldl -pthread
gcc -std=c11 -O2 -Wall -Wextra -Werror -fPIC -shared -DDDD_ALSA_TEST_FAKE \
    -o "$out/libddd_fake_alsa.so" "$src" -pthread
gcc -std=c11 -O2 -Wall -Wextra -Werror -fPIC -shared -DDDD_ALSA_TEST_FAKE -DDDD_ALSA_TEST_NO_RECOVER \
    -o "$out/missing/libddd_fake_alsa.so" "$src" -pthread
gcc -std=c11 -O2 -Wall -Wextra -Werror -DDDD_ALSA_TEST_DRIVER \
    -o "$out/test-driver" "$src" -L"$out" -lddd_fake_alsa -pthread -Wl,--enable-new-dtags,-rpath,'$ORIGIN'
LD_PRELOAD="$out/libddd_alsa_poll_recovery.so" "$out/test-driver"
LD_LIBRARY_PATH="$out/missing" LD_PRELOAD="$out/libddd_alsa_poll_recovery.so" "$out/test-driver" missing-recover
python3 - "$out/libddd_alsa_poll_recovery.so" <<'PY'
import ctypes, errno, sys, time
shim = ctypes.CDLL(sys.argv[1])
for name, args, types in [('snd_pcm_poll_descriptors', [None, None, 0], [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_uint]),
                          ('snd_pcm_avail', [None], [ctypes.c_void_p])]:
    f = getattr(shim, name)
    f.argtypes = types
    f.restype = ctypes.c_long if name == 'snd_pcm_avail' else ctypes.c_int
    start = time.monotonic()
    assert f(*args) == -errno.ENOSYS
    assert time.monotonic() - start >= .020
print('PASS absent ALSA symbols return ENOSYS with backoff')
PY
