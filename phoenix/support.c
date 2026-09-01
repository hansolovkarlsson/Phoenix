/* support.c -- the arena, the source file, and the messages.
 *
 * Nothing here knows what a grammar is.
 */
#include "phx.h"

#include <stdarg.h>
#include <stdlib.h>
#include <string.h>

/* ------------------------------------------------------------------ */
/* Arena
 *
 * A list of blocks. A request larger than a block gets a block of its own, so
 * that one big allocation cannot waste the rest of a shared one.
 */

#define ARENA_BLOCK (64 * 1024)

typedef struct Block Block;
struct Block {
    Block  *next;
    size_t  used;
    size_t  size;
    char    data[];
};

struct Arena {
    Block *head;
};

Arena *arena_new(void)
{
    Arena *a = calloc(1, sizeof *a);
    if (!a) {
        fputs("phx: out of memory\n", stderr);
        exit(2);
    }
    return a;
}

void arena_free(Arena *a)
{
    if (!a) return;
    for (Block *b = a->head; b; ) {
        Block *next = b->next;
        free(b);
        b = next;
    }
    free(a);
}

void *arena_alloc(Arena *a, size_t n)
{
    n = (n + 15) & ~(size_t)15;          /* keep everything 16-byte aligned */

    if (!a->head || a->head->used + n > a->head->size) {
        size_t size = n > ARENA_BLOCK ? n : ARENA_BLOCK;
        Block *b = calloc(1, sizeof *b + size);
        if (!b) {
            fputs("phx: out of memory\n", stderr);
            exit(2);
        }
        b->size = size;
        b->next = a->head;
        a->head = b;
    }

    void *p = a->head->data + a->head->used;
    a->head->used += n;
    return p;
}

char *arena_strndup(Arena *a, const char *s, size_t n)
{
    char *p = arena_alloc(a, n + 1);
    memcpy(p, s, n);
    p[n] = '\0';
    return p;
}

/* ------------------------------------------------------------------ */
/* Source */

static bool read_into(Arena *a, const char *path, Source *out, bool complain)
{
    memset(out, 0, sizeof *out);      /* `map` in particular: callers use the stack */

    FILE *f = fopen(path, "rb");
    if (!f) {
        if (complain) fprintf(stderr, "phx: cannot read %s\n", path);
        return false;
    }

    size_t cap = 8192, size = 0;
    char  *buf = arena_alloc(a, cap);

    for (;;) {
        if (size == cap) {
            char *bigger = arena_alloc(a, cap * 2);
            memcpy(bigger, buf, size);
            buf = bigger;
            cap *= 2;
        }
        size_t got = fread(buf + size, 1, cap - size, f);
        size += got;
        if (got == 0) break;
    }
    fclose(f);

    buf[size] = '\0';
    out->path = path;
    out->text = buf;
    out->size = size;
    return true;
}

bool source_read(Arena *a, const char *path, Source *out)
{
    return read_into(a, path, out, true);
}

bool source_try(Arena *a, const char *path, Source *out)
{
    return read_into(a, path, out, false);
}

/* The stretch of the joined text an offset belongs to. */
static const Unit *unit_at(const Source *src, size_t off)
{
    if (!src->map) return NULL;

    for (int i = src->map->n - 1; i >= 0; i--)
        if (off >= src->map->units[i].start) return &src->map->units[i];

    return src->map->n ? &src->map->units[0] : NULL;
}

const char *source_path_at(const Source *src, size_t off)
{
    const Unit *u = unit_at(src, off);
    return u ? u->path : src->path;
}

void source_position(const Source *src, size_t off, int *line, int *col)
{
    if (off > src->size) off = src->size;

    /* Lines are counted from the start of the file the offset is in, not from
     * the start of the joined text -- otherwise an imported file's line
     * numbers would be its position in a buffer nobody wrote. */
    const Unit *u    = unit_at(src, off);
    size_t      from = u ? u->start : 0;

    int    ln    = 1;
    size_t start = from;
    for (size_t i = from; i < off; i++) {
        if (src->text[i] == '\n') {
            ln++;
            start = i + 1;
        }
    }
    *line = ln;
    *col  = (int)(off - start) + 1;
}

void source_line(const Source *src, size_t off, const char **start, size_t *len)
{
    if (off > src->size) off = src->size;

    /* A line never runs past the end of the file it is in. */
    const Unit *u    = unit_at(src, off);
    size_t      from = u ? u->start : 0;
    size_t      to   = u ? u->start + u->size : src->size;
    if (to > src->size) to = src->size;

    size_t a = off;
    while (a > from && src->text[a - 1] != '\n') a--;

    size_t b = a;
    while (b < to && src->text[b] != '\n') b++;

    *start = src->text + a;
    *len   = b - a;
}

/* ------------------------------------------------------------------ */
/* Diagnostics */

static int errors;

static void report(const char *kind, const Source *src, size_t off,
                   const char *fmt, va_list ap)
{
    if (src) {
        int line, col;
        source_position(src, off, &line, &col);
        fprintf(stderr, "%s:%d:%d: %s: ",
                source_path_at(src, off), line, col, kind);
    } else {
        fprintf(stderr, "phx: %s: ", kind);
    }

    vfprintf(stderr, fmt, ap);
    fputc('\n', stderr);

    if (src) {
        const char *start;
        size_t      len;
        source_line(src, off, &start, &len);

        int line, col;
        source_position(src, off, &line, &col);

        fprintf(stderr, "  %.*s\n  ", (int)len, start);
        for (int i = 1; i < col; i++)
            fputc(start[i - 1] == '\t' ? '\t' : ' ', stderr);
        fputs("^\n", stderr);
    }
}

void diag_error(const Source *src, size_t off, const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    report("error", src, off, fmt, ap);
    va_end(ap);
    errors++;
}

void diag_warn(const Source *src, size_t off, const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    report("warning", src, off, fmt, ap);
    va_end(ap);
}

void diag_note(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    fputs("phx: ", stderr);
    vfprintf(stderr, fmt, ap);
    fputc('\n', stderr);
    va_end(ap);
}

/* ------------------------------------------------------------------ */
/* Counting the work */

Work phx_work;

const Work *work_done(void) { return &phx_work; }
void        work_reset(void) { phx_work = (Work){ 0 }; }

bool diag_failed(void) { return errors > 0; }
int  diag_errors(void) { return errors; }
