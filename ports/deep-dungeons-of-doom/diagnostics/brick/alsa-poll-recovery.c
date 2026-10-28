/* SPDX-License-Identifier: MIT
 * Original process-local recovery for CPAL 0.16's descriptor-fill EPIPE path
 * and invalid available-frame counts from the ALSA rate/dmix plugin chain.
 * Build the normal branch as a shared object. Test branches below provide a fake
 * ALSA library and an executable exercising real LD_PRELOAD symbol interposition.
 */
#define _GNU_SOURCE
#include <errno.h>
#include <limits.h>
#include <poll.h>
#include <pthread.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

/* ALSA's public opaque handle and exact exported C function signatures. */
typedef struct _snd_pcm snd_pcm_t;
int snd_pcm_poll_descriptors(snd_pcm_t *, struct pollfd *, unsigned int);
int snd_pcm_recover(snd_pcm_t *, int, int);
long snd_pcm_avail(snd_pcm_t *);

#if defined(DDD_ALSA_TEST_FAKE)

static _Thread_local int results[2], recovery_result, polls, recoveries;
static _Thread_local int recovery_error, recovery_silent;
static _Thread_local snd_pcm_t *last_pcm;
static _Thread_local unsigned int last_space;
static _Thread_local long available[2];
static _Thread_local unsigned long buffer_frames;
static _Thread_local int param_result, prepare_result, avail_calls, prepare_calls;

void fake_avail_setup(long first, long second, unsigned long buffer, int params, int prepared) {
    available[0] = first; available[1] = second; buffer_frames = buffer;
    param_result = params; prepare_result = prepared;
    avail_calls = prepare_calls = 0;
}
int fake_prepare_calls(void) { return prepare_calls; }
long snd_pcm_avail(snd_pcm_t *pcm) {
    (void)pcm;
    return available[avail_calls++ ? 1 : 0];
}
int snd_pcm_get_params(snd_pcm_t *pcm, unsigned long *buffer, unsigned long *period) {
    (void)pcm; *buffer = buffer_frames; *period = buffer_frames / 2;
    return param_result;
}
int snd_pcm_prepare(snd_pcm_t *pcm) {
    (void)pcm; ++prepare_calls;
    return prepare_result;
}

void fake_setup(int first, int second, int recovered) {
    results[0] = first; results[1] = second; recovery_result = recovered;
    polls = recoveries = recovery_error = recovery_silent = 0;
    last_pcm = NULL; last_space = 0;
}
int fake_polls(void) { return polls; }
int fake_recoveries(void) { return recoveries; }
int fake_recovery_error(void) { return recovery_error; }
int fake_recovery_silent(void) { return recovery_silent; }
snd_pcm_t *fake_pcm(void) { return last_pcm; }
unsigned int fake_space(void) { return last_space; }

int snd_pcm_poll_descriptors(snd_pcm_t *pcm, struct pollfd *fds, unsigned int space) {
    last_pcm = pcm; last_space = space;
    if (space) { fds[0].fd = 73; fds[0].events = POLLOUT; }
    return results[polls++ ? 1 : 0];
}
#ifndef DDD_ALSA_TEST_NO_RECOVER
int snd_pcm_recover(snd_pcm_t *pcm, int error, int silent) {
    if (pcm != last_pcm) abort();
    recoveries++; recovery_error = error; recovery_silent = silent;
    return recovery_result;
}
#endif

#elif defined(DDD_ALSA_TEST_DRIVER)

#include <assert.h>
#include <stdint.h>
#include <string.h>
void fake_setup(int, int, int);
int fake_polls(void), fake_recoveries(void);
int fake_recovery_error(void), fake_recovery_silent(void);
snd_pcm_t *fake_pcm(void);
unsigned int fake_space(void);
void fake_avail_setup(long, long, unsigned long, int, int);
int fake_prepare_calls(void);

static double now_ms(void) {
    struct timespec ts;
    assert(clock_gettime(CLOCK_MONOTONIC, &ts) == 0);
    return ts.tv_sec * 1000.0 + ts.tv_nsec / 1000000.0;
}
static int invoke(void) {
    struct pollfd fds[3] = {{0}};
    snd_pcm_t *token = (snd_pcm_t *)(uintptr_t)0x1234;
    int result = snd_pcm_poll_descriptors(token, fds, 3);
    assert(fake_pcm() == token && fake_space() == 3 && fds[0].fd == 73);
    return result;
}
static void *concurrent(void *unused) {
    (void)unused;
    fake_setup(-EPIPE, 3, 0);
    assert(invoke() == 3);
    assert(fake_polls() == 2 && fake_recoveries() == 1);
    return NULL;
}
int main(int argc, char **argv) {
    if (argc == 2 && strcmp(argv[1], "missing-recover") == 0) {
        fake_setup(-EPIPE, 3, 0);
        double start = now_ms();
        assert(invoke() == -EPIPE);
        assert(now_ms() - start >= 20.0);
        assert(fake_polls() == 1 && fake_recoveries() == 0);
        puts("PASS missing recovery symbol preserves error with backoff");
        return 0;
    }

    /* First calls race through pthread_once, with independent fake PCM state. */
    pthread_t threads[4];
    for (unsigned i = 0; i < 4; ++i) assert(!pthread_create(&threads[i], NULL, concurrent, NULL));
    for (unsigned i = 0; i < 4; ++i) assert(!pthread_join(threads[i], NULL));

    fake_setup(3, 3, 0);
    assert(invoke() == 3 && fake_polls() == 1 && fake_recoveries() == 0);

    fake_setup(-EPIPE, 3, 0);
    assert(invoke() == 3 && fake_polls() == 2 && fake_recoveries() == 1);
    assert(fake_recovery_error() == -EPIPE && fake_recovery_silent() == 0);

    fake_setup(-EPIPE, -EPIPE, 0);
    double start = now_ms();
    assert(invoke() == -EPIPE && fake_polls() == 2 && fake_recoveries() == 1);
    assert(now_ms() - start >= 20.0);

    fake_setup(3, 3, 0); assert(invoke() == 3); /* reset failure backoff */
    fake_setup(-EPIPE, 3, -EIO);
    start = now_ms();
    assert(invoke() == -EIO && fake_polls() == 1 && fake_recoveries() == 1);
    assert(now_ms() - start >= 20.0);

    fake_setup(3, 3, 0); assert(invoke() == 3);
    fake_setup(-ESTRPIPE, -ESTRPIPE, 0);
    start = now_ms();
    assert(invoke() == -ESTRPIPE && fake_recoveries() == 0);
    assert(now_ms() - start >= 20.0);

    fake_setup(3, 3, 0); assert(invoke() == 3);
    fake_setup(-EBADF, -EBADF, 0);
    start = now_ms();
    for (unsigned i = 0; i < 4; ++i) assert(invoke() == -EBADF);
    assert(fake_recoveries() == 0 && fake_polls() == 4);
    assert(now_ms() - start >= 250.0); /* 25 + 50 + 100 + 100 ms */
    snd_pcm_t *pcm = (snd_pcm_t *)(uintptr_t)0x1234;
    fake_avail_setup(2048, 4096, 4096, 0, 0);
    assert(snd_pcm_avail(pcm) == 2048 && fake_prepare_calls() == 0);
    fake_avail_setup(-EPIPE, 4096, 4096, 0, 0);
    assert(snd_pcm_avail(pcm) == -EPIPE && fake_prepare_calls() == 0);
    fake_avail_setup(LONG_MAX, 4096, 4096, 0, 0);
    assert(snd_pcm_avail(pcm) == 4096 && fake_prepare_calls() == 1);
    fake_avail_setup(LONG_MAX, LONG_MAX, 4096, 0, 0);
    assert(snd_pcm_avail(pcm) == -EIO && fake_prepare_calls() == 1);
    fake_avail_setup(LONG_MAX, 4096, 4096, 0, -ENODEV);
    assert(snd_pcm_avail(pcm) == -ENODEV && fake_prepare_calls() == 1);
    fake_avail_setup(LONG_MAX, 4096, 4096, -EBADFD, 0);
    assert(snd_pcm_avail(pcm) == -EBADFD && fake_prepare_calls() == 0);
    fake_avail_setup(4096, 4096, 0, 0, 0);
    assert(snd_pcm_avail(pcm) == -EIO && fake_prepare_calls() == 0);
    puts("PASS concurrent resolution, passthrough, recovery, failed retry, failed recovery, suspend and fatal backoff");
    puts("PASS available-frame bounds, one reset, persistent corruption and ALSA error propagation");
    return 0;
}

#else

#include <dlfcn.h>
#include <string.h>
#include <unistd.h>

typedef int (*poll_fn)(snd_pcm_t *, struct pollfd *, unsigned int);
typedef int (*recover_fn)(snd_pcm_t *, int, int);
typedef long (*avail_fn)(snd_pcm_t *);
typedef int (*params_fn)(snd_pcm_t *, unsigned long *, unsigned long *);
typedef int (*prepare_fn)(snd_pcm_t *);
static poll_fn next_poll;
static recover_fn next_recover;
static avail_fn next_avail;
static params_fn next_params;
static prepare_fn next_prepare;
static pthread_once_t symbols_once = PTHREAD_ONCE_INIT;
static _Thread_local unsigned failures;
static _Thread_local int reported_recovery;
static _Thread_local int reported_invalid_buffer;

static void resolve_symbols(void) {
    void *symbol = dlsym(RTLD_NEXT, "snd_pcm_poll_descriptors");
    _Static_assert(sizeof(symbol) == sizeof(next_poll), "POSIX function pointer ABI required");
    memcpy(&next_poll, &symbol, sizeof(next_poll));
    symbol = dlsym(RTLD_NEXT, "snd_pcm_recover");
    _Static_assert(sizeof(symbol) == sizeof(next_recover), "POSIX function pointer ABI required");
    memcpy(&next_recover, &symbol, sizeof(next_recover));
    symbol = dlsym(RTLD_NEXT, "snd_pcm_avail");
    memcpy(&next_avail, &symbol, sizeof(next_avail));
    symbol = dlsym(RTLD_NEXT, "snd_pcm_get_params");
    memcpy(&next_params, &symbol, sizeof(next_params));
    symbol = dlsym(RTLD_NEXT, "snd_pcm_prepare");
    memcpy(&next_prepare, &symbol, sizeof(next_prepare));
}

static int return_failure(int result) {
    /* A delay on every persistent negative return prevents CPAL's immediate
     * error/retry loop from consuming a core. No ALSA error is converted to
     * success or hidden from the caller. State belongs to this calling thread.
     */
    int saved_errno = errno;
    if (failures < 3) ++failures;
    long milliseconds = 25L << (failures - 1); /* 25, 50, then 100 ms */
    struct timespec delay = {0, milliseconds * 1000000L};
    while (nanosleep(&delay, &delay) < 0 && errno == EINTR) {}
    errno = saved_errno;
    return result;
}

int snd_pcm_poll_descriptors(snd_pcm_t *pcm, struct pollfd *fds, unsigned int space) {
    int once_result = pthread_once(&symbols_once, resolve_symbols);
    if (once_result) return return_failure(-once_result);
    if (!next_poll) return return_failure(-ENOSYS);

    int result = next_poll(pcm, fds, space);
    if (result == -EPIPE && next_recover) {
        if (!reported_recovery) {
            static const char message[] = "ddd-alsa: attempting descriptor underrun recovery\n";
            reported_recovery = 1;
            (void)write(STDERR_FILENO, message, sizeof(message) - 1);
        }
        /* EPIPE recovery prepares the same PCM on its existing owner thread.
         * Do not call recover(ESTRPIPE): ALSA can wait indefinitely for resume.
         */
        int recovered = next_recover(pcm, result, 0);
        if (recovered < 0) return return_failure(recovered);
        result = next_poll(pcm, fds, space); /* exactly one retry */
    }
    if (result < 0) return return_failure(result);
    failures = 0;
    return result;
}

long snd_pcm_avail(snd_pcm_t *pcm) {
    int once_result = pthread_once(&symbols_once, resolve_symbols);
    if (once_result) return return_failure(-once_result);
    if (!next_avail || !next_params || !next_prepare) return return_failure(-ENOSYS);
    long available = next_avail(pcm);
    if (available <= 0) return available;
    unsigned long buffer, period;
    int result = next_params(pcm, &buffer, &period);
    if (result < 0) return return_failure(result);
    if (!buffer) return return_failure(-EIO);
    if ((unsigned long)available <= buffer) return available;
    if (!reported_invalid_buffer) {
        static const char message[] = "ddd-alsa: resetting invalid available-frame count\n";
        reported_invalid_buffer = 1;
        (void)write(STDERR_FILENO, message, sizeof(message) - 1);
    }
    /* An underrun can leave the rate/dmix plugin pointers outside the PCM
     * buffer. Reset the same configured PCM once. Never pass that unbounded
     * count to CPAL's Vec allocation or turn persistent corruption into data.
     */
    result = next_prepare(pcm);
    if (result < 0) return return_failure(result);
    available = next_avail(pcm);
    if (available < 0) return return_failure((int)available);
    if ((unsigned long)available > buffer) return return_failure(-EIO);
    return available;
}
#endif
