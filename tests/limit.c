/* limit.c -- run a program, and stop it if it does not finish.
 *
 *     bin/limit SECONDS program [argument ...]
 *
 * The suite runs programs it has just compiled, and a regression that makes
 * one of them loop forever used to hang `make test` instead of failing it. A
 * harness that cannot say "this did not finish" has only two answers, pass and
 * nothing, and nothing looks like a slow machine for as long as anybody is
 * willing to wait. So every program a harness runs is run through this, and
 * not finishing is a third answer the harness can report by name.
 *
 * It is here and not `timeout(1)` because macOS has no `timeout`, and nothing
 * outside this repository may be needed to run its tests.
 *
 * ---------------------------------------------------------------------------
 * Two ways not to finish
 *
 * A loop that prints is the likelier regression, since most programs here
 * print, and time alone does not catch it: a loop around `printf` writes
 * gigabytes in twenty seconds, and the shell capturing it in `$(...)` runs out
 * of memory and dies before the time is up, which took the whole suite down
 * with it the first time this was tried. So a program is stopped when it has
 * run for SECONDS **or** has written more than PHX_LIMIT_MB megabytes,
 * whichever comes first. The default is 16, which is a thousand times what a
 * program built here prints. The one caller that needs more is the Solveig
 * bytecode oracle: `solvm --trace` over `sola.sol` writes 49 MB, all of it
 * compared, so languages/solveig/tests/bytecode.sh raises it for its traces.
 *
 * Counting what it writes means the program writes into a pipe of this
 * program's and this copies it on. Standard output and standard error get a
 * pipe each, unless they lead to the same place, as under `2>&1`, when they
 * share one: two pipes would let the order of the lines between them change,
 * and some checks compare the two streams together. Standard input is not
 * touched.
 *
 * ---------------------------------------------------------------------------
 * What it answers
 *
 * A program that finishes is invisible: its exit status is passed through,
 * and one killed by a signal is reported as 128 plus the signal, the way a
 * shell reports it.
 *
 * A program that does not finish is stopped, and this exits **124** after
 * writing a sentence beginning `did not finish` to standard error. 124 is
 * what GNU `timeout` uses, so it is the number a reader will already know. It
 * is not unique: a program may exit 124 of its own accord, and a harness that
 * reads exit statuses as data, as the C oracle does, has to look for the
 * sentence as well as the number. The sentence is what cannot collide.
 *
 * When PHX_LIMIT_LOG names a file, the sentence is appended to it as well,
 * with the program's arguments. A check that throws standard error away and
 * expects a failure would take a stopped program for the failure it wanted,
 * and two stopped programs agree with each other; the log is how tests/run.sh
 * sees every stop, whichever harness it happened in and whatever that
 * harness made of it.
 *
 * ---------------------------------------------------------------------------
 * Stopping it
 *
 * The program runs in a process group of its own, and it is the group that is
 * stopped, because the program may be a harness with children of its own and
 * a loop in any of them holds the pipe the caller is reading. The group is
 * sent SIGTERM first and SIGKILL two seconds later. The SIGTERM is not
 * courtesy: a harness under this one may itself be running a program through
 * a second `limit`, in a second group, and SIGKILL cannot be passed on. The
 * inner `limit` catches the SIGTERM and passes it to its own group, so a
 * stop reaches every level.
 *
 * An interrupt from the terminal arrives here and not at the program, which
 * is no longer in the terminal's group, so SIGINT, SIGTERM and SIGHUP are
 * passed on in the same way, and this then dies of the same signal.
 */

#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

enum { DEFAULT_MB = 16 };

enum { GRACE = 2, EXPIRED = 124, UNUSABLE = 125, UNRUNNABLE = 127 };

/* One stream being copied: the read end of the pipe the program writes to,
 * and where it goes. `from` is -1 once the pipe is closed. */
struct stream {
    int from;
    int to;
};

/* The output limit in megabytes; see the head of this file. */
static long limit_mb = DEFAULT_MB;

static volatile sig_atomic_t passed_on;

/* A pipe to itself, written to when the program ends, so that waiting for
 * output and waiting for the end are one poll and neither is a timer. */
static int wake[2];

static void on_stop(int sig) { passed_on = sig; }

static void on_child(int sig)
{
    int saved = errno;
    (void)!write(wake[1], "", 1);
    errno = saved;
}

static double now(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (double)t.tv_sec + (double)t.tv_nsec / 1e9;
}

/* Whether fds 1 and 2 lead to the same file, pipe or terminal. */
static int same_place(void)
{
    struct stat a, b;
    return fstat(1, &a) == 0 && fstat(2, &b) == 0
        && a.st_dev == b.st_dev && a.st_ino == b.st_ino;
}

/* Copies what is waiting on `s`, and returns how many bytes that was. A
 * reader that has gone away, as under `| head -2`, is treated the way the
 * program would have been: the pipe is closed, and its next write fails. */
static long copy(struct stream *s)
{
    char buf[65536];
    ssize_t n = read(s->from, buf, sizeof buf), off = 0;

    if (n < 0 && errno == EINTR)
        return 0;
    if (n <= 0) {
        close(s->from);
        s->from = -1;
        return 0;
    }
    while (off < n) {
        ssize_t w = write(s->to, buf + off, (size_t)(n - off));
        if (w < 0 && errno == EINTR)
            continue;
        if (w < 0) {
            close(s->from);
            s->from = -1;
            break;
        }
        off += w;
    }
    return (long)n;
}

/* The sentence, and in the log the whole command line after it, since a
 * log line has no check around it to say which run it was. */
static void report(FILE *f, char **argv, long secs, int overflowed, int whole)
{
    if (overflowed)
        fprintf(f, "%s: did not finish, and was stopped after writing %ld MB",
                argv[2], limit_mb);
    else
        fprintf(f, "%s: did not finish in %ld s", argv[2], secs);
    if (whole) {
        char **a;
        fputs(":", f);
        for (a = argv + 3; *a; a++)
            fprintf(f, " %s", *a);
    }
    fputc('\n', f);
}

int main(int argc, char **argv)
{
    char *end;
    long secs, written = 0;
    pid_t pid;
    int out[2], err[2] = { -1, -1 }, shared, status = 0, reaped = 0;
    int forwarded = 0, stage = 0, overflowed = 0;
    struct stream streams[2];
    int nstreams;
    double deadline;
    struct sigaction sa;

    if (argc < 3) {
        fprintf(stderr, "usage: limit SECONDS program [argument ...]\n");
        return UNUSABLE;
    }
    errno = 0;
    secs = strtol(argv[1], &end, 10);
    if (errno || *end || end == argv[1] || secs <= 0 || secs > 86400) {
        fprintf(stderr, "limit: '%s' is not a number of seconds\n", argv[1]);
        return UNUSABLE;
    }
    if ((end = getenv("PHX_LIMIT_MB")) != NULL && *end) {
        char *mb_end;
        errno = 0;
        limit_mb = strtol(end, &mb_end, 10);
        if (errno || *mb_end || limit_mb <= 0 || limit_mb > 65536) {
            fprintf(stderr, "limit: PHX_LIMIT_MB '%s' is not a number of "
                    "megabytes\n", end);
            return UNUSABLE;
        }
    }

    shared = same_place();
    if (pipe(out) < 0 || (!shared && pipe(err) < 0) || pipe(wake) < 0) {
        perror("limit: pipe");
        return UNUSABLE;
    }
    fcntl(wake[0], F_SETFD, FD_CLOEXEC);
    fcntl(wake[1], F_SETFD, FD_CLOEXEC);
    fcntl(wake[0], F_SETFL, O_NONBLOCK);
    fcntl(wake[1], F_SETFL, O_NONBLOCK);

    memset(&sa, 0, sizeof sa);
    sigemptyset(&sa.sa_mask);
    sa.sa_handler = on_stop; /* no SA_RESTART: poll has to wake up */
    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGTERM, &sa, NULL);
    sigaction(SIGHUP, &sa, NULL);
    sa.sa_handler = on_child;
    sigaction(SIGCHLD, &sa, NULL);
    sa.sa_handler = SIG_IGN;
    sigaction(SIGPIPE, &sa, NULL);

    pid = fork();
    if (pid < 0) {
        perror("limit: fork");
        return UNUSABLE;
    }
    if (pid == 0) {
        /* The handlers above are reset to the default by exec; an ignored
         * SIGPIPE would not be, so it is put back by hand. */
        signal(SIGPIPE, SIG_DFL);
        setpgid(0, 0);
        dup2(out[1], 1);
        dup2(shared ? out[1] : err[1], 2);
        close(out[0]);
        close(out[1]);
        if (!shared) {
            close(err[0]);
            close(err[1]);
        }
        execvp(argv[2], argv + 2);
        fprintf(stderr, "limit: cannot run %s: %s\n", argv[2], strerror(errno));
        _exit(UNRUNNABLE);
    }
    /* Both sides set the group, so it is set whichever runs first. */
    setpgid(pid, pid);

    close(out[1]);
    streams[0].from = out[0];
    streams[0].to = 1;
    nstreams = 1;
    if (!shared) {
        close(err[1]);
        streams[1].from = err[0];
        streams[1].to = 2;
        nstreams = 2;
    }

    deadline = now() + (double)secs;
    for (;;) {
        struct pollfd fds[3];
        int nfds = 0, i, live = 0, wait_ms;
        double left;

        /* Reaped before the test for being done, never after: the wake byte
         * for this end may already have been read, and a poll after it
         * would then sleep until the deadline with nothing left to wake it.
         * That was a program finished in a millisecond and reported ok
         * twenty seconds later, at random, until the order was this. */
        if (!reaped) {
            pid_t r = waitpid(pid, &status, WNOHANG);
            if (r == pid)
                reaped = 1;
            else if (r < 0 && errno != EINTR) {
                perror("limit: waitpid");
                return UNUSABLE;
            }
        }
        for (i = 0; i < nstreams; i++)
            live += streams[i].from >= 0;
        if (reaped && !live)
            break;
        if (passed_on && !forwarded) {
            forwarded = 1;
            kill(-pid, passed_on);
        }

        left = deadline - now();
        if (left <= 0 || (overflowed && stage == 0)) {
            if (stage == 0) {
                kill(-pid, SIGTERM);
            } else if (stage == 1) {
                kill(-pid, SIGKILL);
            } else {
                /* Something outside the group is holding a pipe open, and
                 * nothing more can be done about it from here. */
                break;
            }
            stage++;
            deadline = now() + GRACE;
            left = GRACE;
        }

        wait_ms = (int)(left * 1000) + 1;
        fds[nfds].fd = wake[0];
        fds[nfds].events = POLLIN;
        fds[nfds].revents = 0;
        nfds++;
        for (i = 0; i < nstreams; i++)
            if (streams[i].from >= 0) {
                fds[nfds].fd = streams[i].from;
                fds[nfds].events = POLLIN;
                fds[nfds].revents = 0;
                nfds++;
            }
        if (poll(fds, (nfds_t)nfds, wait_ms) < 0 && errno != EINTR) {
            perror("limit: poll");
            return UNUSABLE;
        }
        if (fds[0].revents) {
            char drain[64];
            while (read(wake[0], drain, sizeof drain) > 0)
                ;
        }
        for (i = 0; i < nstreams; i++) {
            int j;
            for (j = 1; j < nfds; j++)
                if (streams[i].from == fds[j].fd && fds[j].revents)
                    written += copy(&streams[i]);
        }
        if (written > limit_mb * 1024 * 1024)
            overflowed = 1;
    }
    if (!reaped)
        waitpid(pid, &status, 0);

    if (passed_on) {
        signal(passed_on, SIG_DFL);
        raise(passed_on);
    }
    /* However it then ended: a shell that is sent SIGTERM may run its exit
     * trap and exit 143 rather than die of the signal. */
    if (stage > 0) {
        const char *log = getenv("PHX_LIMIT_LOG");
        report(stderr, argv, secs, overflowed, 0);
        if (log && *log) {
            FILE *f = fopen(log, "a");
            if (f) {
                report(f, argv, secs, overflowed, 1);
                fclose(f);
            }
        }
        return EXPIRED;
    }
    if (WIFEXITED(status))
        return WEXITSTATUS(status);
    if (WIFSIGNALED(status))
        return 128 + WTERMSIG(status);
    return UNUSABLE;
}
