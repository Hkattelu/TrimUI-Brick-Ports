/* MIT. Prepare an exact supported DDD movie from the player's own files.
 * Run with cwd = the port directory. No save paths are opened or modified.
 */
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/file.h>
#include <unistd.h>
#include <openssl/sha.h>
#include <zlib.h>

struct input { const char *path, *sha; size_t bytes; int swf; };
struct copy { size_t offset, bytes; };
#include "recipe.h"
#define COUNT(a) (sizeof(a) / sizeof((a)[0]))

static void fail(const char *message) { fprintf(stderr, "DDD setup: %s\n", message); exit(1); }
static int hash_ok(const unsigned char *data, size_t size, const char *expected) {
    unsigned char digest[SHA256_DIGEST_LENGTH]; char hex[65];
    SHA256(data, size, digest);
    for (size_t i=0; i<sizeof(digest); ++i) sprintf(hex+2*i, "%02x", digest[i]);
    return strcmp(hex, expected) == 0;
}
/* Open each component relative to its directory descriptor. Never follow a
 * symlink in gamedata or replace a symlink/output unexpectedly. */
static int open_input(int dir, const char *path) {
    char name[512];
    if (strlen(path) >= sizeof(name)) fail("Input path too long.");
    strcpy(name, path);
    int current = dup(dir); if (current < 0) fail("Cannot open game folder.");
    char *save = NULL, *part = strtok_r(name, "/", &save);
    while (part) {
        char *next = strtok_r(NULL, "/", &save);
        int fd = openat(current, part, O_RDONLY | O_NOFOLLOW | (next ? O_DIRECTORY : 0));
        close(current); current = fd;
        if (fd < 0) return -1;
        part = next;
    }
    return current;
}
static unsigned char *read_exact(int fd, size_t bytes) {
    struct stat st;
    if (fstat(fd, &st) || !S_ISREG(st.st_mode) || st.st_size != (off_t)bytes) return NULL;
    unsigned char *data = malloc(bytes ? bytes : 1); if (!data) fail("Out of memory.");
    size_t n = 0;
    while (n < bytes) { ssize_t got = read(fd, data+n, bytes-n); if (got <= 0) { free(data); return NULL; } n += (size_t)got; }
    return data;
}
static uint32_t u32(const unsigned char *p) { return (uint32_t)p[0] | (uint32_t)p[1]<<8 | (uint32_t)p[2]<<16 | (uint32_t)p[3]<<24; }

int main(void) {
    int lock = open(".ddd-prepare.lock", O_RDWR | O_CREAT | O_NOFOLLOW, 0600);
    if (lock < 0 || flock(lock, LOCK_EX | LOCK_NB)) fail("Another preparation is running, or the setup lock cannot be opened.");
    int existing = open("ddd.swf", O_RDONLY | O_NOFOLLOW);
    if (existing >= 0) {
        unsigned char *data = read_exact(existing, RESULT_BYTES); close(existing);
        int ok = data && hash_ok(data, RESULT_BYTES, RESULT_SHA); free(data);
        if (ok) { puts("DDD is already prepared."); return 0; }
        fail("Existing ddd.swf is not this build. Back it up and remove it before retrying. Saves are unchanged.");
    }
    if (errno != ENOENT) fail("Cannot safely open ddd.swf.");
    int dir = open("gamedata", O_RDONLY | O_DIRECTORY | O_NOFOLLOW);
    if (dir < 0) fail("Copy the complete Windows Steam game folder contents into deepdungeonsofdoom/gamedata, then launch again.");
    unsigned char *base = malloc(BASE_BYTES); if (!base) fail("Out of memory.");
    size_t cursor = 0;
    for (size_t i=0; i<COUNT(inputs); ++i) {
        const struct input *in = &inputs[i];
        int fd = open_input(dir, in->path);
        unsigned char *data = fd < 0 ? NULL : read_exact(fd, in->bytes);
        if (fd >= 0) close(fd);
        if (!data || !hash_ok(data, in->bytes, in->sha)) {
            fprintf(stderr, "Missing or unsupported game file: %s\n", in->path);
            fail("Copy a complete supported Windows Steam installation, including META-INF. Originals and saves are unchanged.");
        }
        if (in->swf) {
            if (in->bytes < 8 || data[1]!='W' || data[2]!='S') fail("Invalid SWF header.");
            size_t length = u32(data+4);
            if (length < 8 || length > BASE_BYTES-cursor) fail("Invalid SWF size.");
            memcpy(base+cursor, data, 8); base[cursor]='F';
            if (data[0]=='C') {
                uLongf decoded = length-8;
                if (uncompress(base+cursor+8, &decoded, data+8, in->bytes-8)!=Z_OK || decoded!=length-8) fail("Game decompression failed.");
            } else if (data[0]=='F' && length==in->bytes) memcpy(base+cursor+8, data+8, length-8);
            else fail("Unsupported SWF compression.");
            cursor += length;
        }
        free(data);
    }
    close(dir);
    if (cursor!=BASE_BYTES) fail("Unexpected source size.");
    unsigned char *result = malloc(RESULT_BYTES); if (!result) fail("Out of memory.");
    cursor=0;
    for (size_t i=0; i<COUNT(copies); ++i) {
        struct copy c=copies[i];
        if (c.offset>BASE_BYTES || c.bytes>BASE_BYTES-c.offset || c.bytes>RESULT_BYTES-cursor) fail("Invalid preparation recipe.");
        memcpy(result+cursor, base+c.offset, c.bytes); cursor+=c.bytes;
    }
    free(base);
    if (cursor!=RESULT_BYTES || !hash_ok(result, RESULT_BYTES, RESULT_SHA)) fail("Prepared game verification failed.");
    char temporary[]=".ddd-prepared-XXXXXX";
    int fd=mkstemp(temporary); if(fd<0) fail("Cannot create prepared file. Check free space.");
    cursor=0;
    while(cursor<RESULT_BYTES) {
        ssize_t n=write(fd,result+cursor,RESULT_BYTES-cursor);
        if(n<=0) { close(fd); unlink(temporary); fail("Writing failed. Check free space."); }
        cursor+=(size_t)n;
    }
    free(result);
    int sync_result=fsync(fd); int close_result=close(fd);
    if(sync_result || close_result) { unlink(temporary); fail("Could not save prepared file."); }
    /* The launch wrapper holds a lock. rename is atomic and works on SD FAT/exFAT. */
    struct stat st;
    if(lstat("ddd.swf", &st)==0 || errno!=ENOENT) { unlink(temporary); fail("Output appeared during preparation; retry."); }
    if(rename(temporary,"ddd.swf")) { unlink(temporary); fail("Could not install prepared file."); }
    puts("DDD preparation complete.");
    return 0;
}
