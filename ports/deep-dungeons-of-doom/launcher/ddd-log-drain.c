/* Keep consuming a producer's log after its on-disk budget is exhausted. */
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static volatile sig_atomic_t stopping;
static void stop(int signo) { (void)signo; stopping = 1; }

int main(int argc, char **argv) {
    char *end;
    unsigned long long limit;
    if (argc != 3 || !*argv[2] || *argv[2] == '-') return 2;
    errno = 0;
    limit = strtoull(argv[2], &end, 10);
    if (errno || *end || !limit || limit > 16777216) return 2;
    struct sigaction action = {0};
    action.sa_handler = stop;
    sigemptyset(&action.sa_mask);
    if (sigaction(SIGTERM, &action, NULL) || sigaction(SIGINT, &action, NULL) ||
        sigaction(SIGHUP, &action, NULL)) return 2;

    /* An unavailable/full log must not close the producer's pipe. */
    int fd = open(argv[1], O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600);
    int failed = fd < 0;
    unsigned long long written = 0;
    char buffer[8192];
    while (!stopping) {
        ssize_t count = read(STDIN_FILENO, buffer, sizeof(buffer));
        if (!count) break;
        if (count < 0) {
            if (errno == EINTR) continue;
            failed = 1;
            break;
        }
        size_t keep = (size_t)count;
        if ((unsigned long long)keep > limit - written) keep = (size_t)(limit - written);
        size_t offset = 0;
        while (fd >= 0 && offset < keep && !stopping) {
            ssize_t result = write(fd, buffer + offset, keep - offset);
            if (result < 0 && errno == EINTR) continue;
            if (result <= 0) {
                failed = 1;
                close(fd);
                fd = -1;
                break;
            }
            offset += (size_t)result;
            written += (unsigned long long)result;
        }
    }
    if (fd >= 0 && close(fd)) failed = 1;
    return stopping ? 0 : failed;
}
