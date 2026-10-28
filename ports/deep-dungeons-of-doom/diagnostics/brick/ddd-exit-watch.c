/* Private DDD launcher helper. Reads evdev without grabbing or consuming another
 * reader's events. Requests SIGTERM only for the caller's verified runtime PID. */
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <linux/input.h>
#include <poll.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#define COMMAND_BYTES 8192
static volatile sig_atomic_t stopping;
struct target { pid_t pid; unsigned long long start; size_t size; char command[COMMAND_BYTES]; };
struct chord { int select_down, start_down, armed, dropped, requested; };

static void stop_watch(int signal_number) { (void)signal_number; stopping = 1; }
static ssize_t proc_read(pid_t pid, const char *name, char *buffer, size_t capacity) {
    char path[64];
    snprintf(path, sizeof(path), "/proc/%ld/%s", (long)pid, name);
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) return -1;
    ssize_t count;
    do { count = read(fd, buffer, capacity - 1); } while (count < 0 && errno == EINTR);
    close(fd);
    if (count < 0 || (size_t)count >= capacity - 1) return -1;
    buffer[count] = '\0';
    return count;
}
static int start_time(pid_t pid, unsigned long long *value) {
    char text[4096], *cursor, *state;
    if (proc_read(pid, "stat", text, sizeof(text)) <= 0) return 0;
    cursor = strrchr(text, ')'); /* comm may contain spaces and parentheses. */
    if (!cursor) return 0;
    cursor++;
    for (int field = 3; field <= 22; field++) {
        char *word = strtok_r(field == 3 ? cursor : NULL, " \t\n", &state);
        if (!word) return 0;
        if (field == 22) {
            char *end;
            errno = 0;
            *value = strtoull(word, &end, 10);
            return !errno && *word && !*end;
        }
    }
    return 0;
}
static int same_target(const struct target *target) {
    unsigned long long start;
    char command[COMMAND_BYTES];
    if (!start_time(target->pid, &start) || start != target->start) return 0;
    ssize_t count = proc_read(target->pid, "cmdline", command, sizeof(command));
    return count > 0 && (size_t)count == target->size &&
           !memcmp(command, target->command, target->size) &&
           start_time(target->pid, &start) && start == target->start;
}
static int load_target(struct target *target, const char *runtime, const char *movie) {
    if (runtime[0] != '/' || movie[0] != '/') return 0;
    unsigned long long actual;
    if (!start_time(target->pid, &actual) || actual != target->start) return 0;
    ssize_t count = proc_read(target->pid, "cmdline", target->command, sizeof(target->command));
    if (count <= 0 || target->command[count - 1] != '\0') return 0;
    target->size = (size_t)count;
    int runtime_count = 0, movie_count = 0;
    const char *last = NULL;
    for (size_t at = 0; at < target->size;) {
        const char *word = target->command + at;
        const char *end = memchr(word, '\0', target->size - at);
        if (!end) return 0;
        runtime_count += !strcmp(word, runtime);
        movie_count += !strcmp(word, movie);
        last = word;
        at = (size_t)(end - target->command) + 1;
    }
    return runtime_count == 1 && movie_count == 1 && last && !strcmp(last, movie) && same_target(target);
}
static void update_chord(struct chord *chord, const struct input_event *event) {
    if (chord->dropped) {
        if (event->type == EV_SYN && event->code == SYN_REPORT) chord->dropped = 0;
        return; /* Discard the entire stale packet, including key releases. */
    }
    if (event->type == EV_SYN && event->code == SYN_DROPPED) {
        /* Require fresh releases after an overrun; never infer a held chord. */
        chord->select_down = chord->start_down = 1;
        chord->armed = 0;
        chord->dropped = 1;
        chord->requested = 0;
        return;
    }
    if (event->type != EV_KEY || event->value < 0 || event->value > 2) return;
    if (event->code == BTN_SELECT) chord->select_down = event->value != 0;
    else if (event->code == BTN_START) chord->start_down = event->value != 0;
    else return;
    if (!chord->select_down && !chord->start_down) chord->armed = 1;
    /* Neither button is mapped into DDD. Accept a fresh second-button press,
     * including Start held while Select is tapped, in either order. Latch it
     * across a release in the same read; repeats alone must never request exit. */
    if (chord->armed && chord->select_down && chord->start_down && event->value == 1)
        chord->requested = 1;
}
static int watch_events(int fd, const struct target *target, pid_t parent, struct chord chord) {
    unsigned char bytes[sizeof(struct input_event) * 16];
    size_t used = 0;
    while (!stopping) {
        if (getppid() != parent || !same_target(target)) return 4;
        struct pollfd input = { .fd = fd, .events = POLLIN };
        int ready = poll(&input, 1, 20);
        if (ready < 0) { if (errno == EINTR) continue; return 3; }
        if (input.revents & (POLLERR | POLLHUP | POLLNVAL)) return 3;
        if (input.revents & POLLIN) {
            ssize_t count = read(fd, bytes + used, sizeof(bytes) - used);
            if (count < 0) { if (errno == EAGAIN || errno == EINTR) continue; return 3; }
            if (!count) return 3;
            used += (size_t)count;
            size_t at = 0;
            while (used - at >= sizeof(struct input_event)) {
                struct input_event event;
                memcpy(&event, bytes + at, sizeof(event));
                update_chord(&chord, &event);
                at += sizeof(event);
            }
            memmove(bytes, bytes + at, used - at);
            used -= at;
        }
        if (chord.requested) {
            if (stopping || getppid() != parent || !same_target(target)) return 4;
            if (kill(target->pid, SIGTERM)) return 4;
            fprintf(stderr, "DDD exit requested for the verified runtime process.\n");
            return 0;
        }
    }
    return 0;
}
int main(int argc, char **argv) {
    if (argc != 6) {
        fprintf(stderr, "Usage: ddd-exit-watch EVENT_DEVICE PID START_TICKS ABS_RUNTIME ABS_MOVIE\n");
        return 2;
    }
    pid_t parent = getppid();
    if (parent <= 1) return 4;
    char *end;
    errno = 0;
    long pid = strtol(argv[2], &end, 10);
    if (errno || !*argv[2] || *end || pid <= 1 || pid > INT_MAX || pid == getpid()) return 2;
    struct target target = { .pid = (pid_t)pid };
    errno = 0;
    target.start = strtoull(argv[3], &end, 10);
    if (errno || !*argv[3] || *end || !target.start || argv[3][0] == '-') return 2;
    if (!load_target(&target, argv[4], argv[5])) return 4;
    int fd = open(argv[1], O_RDONLY | O_NONBLOCK | O_CLOEXEC);
    if (fd < 0) return 3;
    char name[128] = {0};
    unsigned char keys[(KEY_MAX + 8) / 8] = {0};
    if (ioctl(fd, EVIOCGNAME(sizeof(name) - 1), name) < 0 || strcmp(name, "TRIMUI Player1") ||
        ioctl(fd, EVIOCGKEY(sizeof(keys)), keys) < 0) {
        fprintf(stderr, "Expected readable TRIMUI Player1 evdev device.\n");
        close(fd);
        return 3;
    }
    struct chord chord = {
        .select_down = !!(keys[BTN_SELECT / 8] & (1U << (BTN_SELECT % 8))),
        .start_down = !!(keys[BTN_START / 8] & (1U << (BTN_START % 8)))
    };
    chord.armed = !chord.select_down && !chord.start_down;
    struct sigaction action = { .sa_handler = stop_watch };
    sigemptyset(&action.sa_mask);
    sigaction(SIGTERM, &action, NULL);
    sigaction(SIGINT, &action, NULL);
    sigaction(SIGHUP, &action, NULL);
    int result = watch_events(fd, &target, parent, chord);
    close(fd);
    return result;
}
