#define main production_main
#include "../ddd-exit-watch.c"
#undef main
#include <assert.h>
#include <sys/wait.h>
#include <time.h>

static void sleep_ms(long ms) {
    struct timespec delay = {ms / 1000, (ms % 1000) * 1000000};
    while (nanosleep(&delay, &delay) && errno == EINTR) {}
}
static void alive(pid_t pid) { int status; assert(waitpid(pid,&status,WNOHANG)==0); }
static void event(int fd, unsigned short type, unsigned short code, int value) {
    struct input_event input = {.type=type, .code=code, .value=value};
    assert(write(fd, &input, sizeof(input)) == sizeof(input));
}
static pid_t watcher(int fd, const struct target *target, pid_t parent) {
    pid_t pid=fork(); assert(pid>=0);
    if (!pid) {
        signal(SIGTERM, stop_watch);
        struct chord chord = {.armed=1};
        _exit(watch_events(fd,target,parent,chord));
    }
    return pid;
}
int main(int argc,char **argv) {
    if (argc==3 && !strcmp(argv[1],"--target")) { alarm(30); for (;;) pause(); }
    if (argv[0][0] != '/') { fputs("Run this test by its absolute executable path.\n",stderr); return 2; }
    pid_t target_pid=fork(); assert(target_pid>=0);
    if (!target_pid) { execl(argv[0],argv[0],"--target","/ddd-exit-watch-test.swf",(char*)NULL); _exit(99); }
    struct target target={.pid=target_pid};
    for (int i=0;i<100;i++) {
        if (start_time(target_pid,&target.start) && load_target(&target,argv[0],"/ddd-exit-watch-test.swf")) break;
        sleep_ms(10);
    }
    assert(load_target(&target,argv[0],"/ddd-exit-watch-test.swf"));
    struct target wrong=target; wrong.start++; assert(!same_target(&wrong));
    wrong=target; wrong.command[0]^=1; assert(!same_target(&wrong));
    assert(!load_target(&wrong,"/wrong/runtime","/ddd-exit-watch-test.swf"));
    wrong=target; assert(!load_target(&wrong,argv[0],"/ddd-exit-watch-wrong.swf"));
    char pid_text[32], start_text[32];
    snprintf(pid_text,sizeof(pid_text),"%ld",(long)target_pid);
    snprintf(start_text,sizeof(start_text),"%llu",target.start);
    char *bad_device[]={"watch","/dev/null",pid_text,start_text,argv[0],"/ddd-exit-watch-test.swf"};
    assert(production_main(6,bad_device)==3); alive(target_pid);
    int pipes[2]; assert(pipe(pipes)==0);
    pid_t watch=watcher(pipes[0],&target,getpid()+100000);
    int status; assert(waitpid(watch,&status,0)==watch && WIFEXITED(status) && WEXITSTATUS(status)==4);
    alive(target_pid);
    watch=watcher(pipes[0],&target,getpid());
    sleep_ms(50); assert(kill(watch,SIGTERM)==0);
    assert(waitpid(watch,&status,0)==watch && WIFEXITED(status) && WEXITSTATUS(status)==0);
    alive(target_pid);
    watch=watcher(pipes[0],&target,getpid());
    /* Singles, including a long Start hold, must not exit. */
    event(pipes[1],EV_KEY,BTN_SELECT,1);
    sleep_ms(150); alive(target_pid);
    event(pipes[1],EV_KEY,BTN_SELECT,0);
    event(pipes[1],EV_KEY,BTN_START,1);
    sleep_ms(850); alive(target_pid);
    event(pipes[1],EV_KEY,BTN_START,0);
    /* A split record exercises buffering without a real input device. */
    struct input_event first={.type=EV_KEY,.code=BTN_START,.value=1};
    assert(write(pipes[1],&first,5)==5); sleep_ms(30);
    assert(write(pipes[1],((char*)&first)+5,sizeof(first)-5)==sizeof(first)-5);
    sleep_ms(50); alive(target_pid);
    /* Replay the user's Start-held, short Select tap. Put press/release in one
     * write so draining the buffer cannot erase the request. */
    struct input_event tap[2] = {
        {.type=EV_KEY,.code=BTN_SELECT,.value=1},
        {.type=EV_KEY,.code=BTN_SELECT,.value=0}
    };
    assert(write(pipes[1],tap,sizeof(tap))==sizeof(tap));
    sleep_ms(150);
    assert(waitpid(target_pid,&status,0)==target_pid && WIFSIGNALED(status) && WTERMSIG(status)==SIGTERM);
    assert(waitpid(watch,&status,0)==watch && WIFEXITED(status) && WEXITSTATUS(status)==0);
    close(pipes[0]); close(pipes[1]);
    struct chord initial={.select_down=1,.start_down=1,.armed=0};
    struct input_event release={.type=EV_KEY,.code=BTN_SELECT,.value=0};
    update_chord(&initial,&release); assert(!initial.armed && !initial.requested);
    release.code=BTN_START; update_chord(&initial,&release); assert(initial.armed && !initial.requested);
    struct input_event lost={.type=EV_SYN,.code=SYN_DROPPED};
    update_chord(&initial,&lost); assert(!initial.armed && !initial.requested);
    release.code=BTN_SELECT; update_chord(&initial,&release);
    release.code=BTN_START; update_chord(&initial,&release);
    release.value=1; update_chord(&initial,&release);
    release.code=BTN_SELECT; update_chord(&initial,&release);
    assert(initial.dropped && !initial.armed && !initial.requested);
    struct input_event report={.type=EV_SYN,.code=SYN_REPORT};
    update_chord(&initial,&report);
    assert(!initial.dropped && !initial.armed && !initial.requested);
    release.value=0; update_chord(&initial,&release);
    assert(!initial.armed);
    release.code=BTN_START; update_chord(&initial,&release);
    assert(initial.armed && !initial.requested);
    /* Reverse-order chord and repeats: only a fresh second press triggers. */
    initial=(struct chord){.armed=1};
    release.code=BTN_SELECT; release.value=1; update_chord(&initial,&release);
    assert(!initial.requested);
    release.code=BTN_START; release.value=2; update_chord(&initial,&release);
    assert(!initial.requested);
    release.value=1; update_chord(&initial,&release); assert(initial.requested);
    update_chord(&initial,&lost); assert(!initial.requested && !initial.armed);
    puts("PASS: exact identity, parent guard, stoppable watcher, short chord in both orders, single/repeat/split input, startup release and overrun guards");
    return 0;
}
