/* include.c -- a target language's own includes.
 *
 * `%import` splices one description into another; this is the same thing one
 * level down, for the language being described.
 *
 * ---------------------------------------------------------------------------
 * Why it is not a pass
 *
 * Every other thing a description says about meaning is a clause, and the
 * first question here was whether this could be one too. It cannot, and the
 * reason is the definition of a pass: **a walk over one tree that has already
 * been read.** An include is a second file, which has to be read before there
 * is a tree to walk. No clause can reach it, however it is written.
 *
 * So this runs once, between the parser and the first pass, and everything
 * after it sees a single tree that never mentions a second file. A backend
 * needs no clause for an include and cannot encounter one.
 *
 * ---------------------------------------------------------------------------
 * What the description has to say
 *
 *     %include Include path .
 *
 * The node that stands for an include, and the field that holds the name of
 * the file. That is the whole of the notation, and nothing in this file knows
 * anything about any particular language.
 *
 * The field's text is used **exactly as it stands**, which is a decision worth
 * naming: a token arrives spelled the way the file spelled it, quotes and all,
 * and stripping them here would mean guessing how the target writes a string.
 * The description already has the means to say it -- Solveig's include builds
 * `Include(path: slice($p, 2, size($p) - 1))` -- so the guess is not needed.
 *
 * ---------------------------------------------------------------------------
 * What a splice is
 *
 * The include node is replaced, **in the list that holds it**, by the items
 * the included file's root holds. A file's root is a list, or a node with one
 * field which is a list -- Solveig's `Program(body: [...])` -- and anything
 * else is refused, because there is no answer to which half of a root with two
 * parts a statement position wants.
 *
 * An include that is not in a list is refused for the same reason from the
 * other side: a file has nowhere to go where one value is expected.
 *
 * ---------------------------------------------------------------------------
 * Three new ways to fail, which is what made this worth being careful about
 *
 * A reader that reads one file can fail in one way. A reader that follows
 * files fails in three more, and each gets a message at the position of the
 * include that caused it:
 *
 *   - **the file is not there.** The message says where it was looked for,
 *     because "beside the includer, then the search path" is exactly the rule
 *     nobody can reconstruct from a bare failure.
 *   - **relative to which file?** Beside the file the include is *written in*,
 *     never the one the command line named, so a program keeps working when it
 *     is moved. That is C's rule for `#include "..."` and it is C's reason.
 *   - **a cycle.** Not detected, because there is nothing to detect: a file is
 *     read once however many ways it is reached, so a file that comes round to
 *     itself finds itself already read and contributes nothing. Two files that
 *     include each other terminate for the same reason `%import` does.
 */
#include "phx.h"

#include <string.h>

typedef struct {
    Arena             *a;
    const Grammar     *g;
    Source            *src;       /* the joined text, grown as files arrive  */
    SourceMap         *map;
    const IncludePath *look;

    char             **done;      /* the files already read, by identity     */
    int                ndone;
    int                capdone;

    int                depth;     /* only to keep a runaway from the stack   */
    bool               ok;
} Includer;

/* A file that includes a file that includes a file. Nothing sensible is this
 * deep, and a reader that recurses wants a floor under it whatever the
 * once-only rule promises. */
#define INCLUDE_DEPTH 64

/* ------------------------------------------------------------------ */
/* Paths */

void include_path_add(Arena *a, IncludePath *look, const char *dir)
{
    if (look->n == look->cap) {
        int          cap = look->cap ? look->cap * 2 : 4;
        const char **big = arena_alloc(a, (size_t)cap * sizeof *big);
        memcpy(big, look->dirs, (size_t)look->n * sizeof *big);
        look->dirs = big;
        look->cap  = cap;
    }
    look->dirs[look->n++] = dir;
}

/* `dir/of/includer` + `named` */
static char *path_beside(Arena *a, const char *beside, const char *name)
{
    const char *slash = strrchr(beside, '/');
    if (!slash) return arena_strndup(a, name, strlen(name));

    size_t dir = (size_t)(slash - beside) + 1;
    size_t n   = strlen(name);
    char  *out = arena_alloc(a, dir + n + 1);

    memcpy(out, beside, dir);
    memcpy(out + dir, name, n);
    out[dir + n] = '\0';
    return out;
}

/* `dir` + `/` + `named`, for a search path entry, which is a directory rather
 * than a file and so has no name to strip off the end. */
static char *path_under(Arena *a, const char *dir, const char *name)
{
    size_t d = strlen(dir);
    size_t n = strlen(name);
    bool   sep = d && dir[d - 1] != '/';
    char  *out = arena_alloc(a, d + (sep ? 1 : 0) + n + 1);

    memcpy(out, dir, d);
    if (sep) out[d++] = '/';
    memcpy(out + d, name, n);
    out[d + n] = '\0';
    return out;
}

/* Two spellings of one file, told apart.
 *
 * `a/./b`, `a//b` and `a/x/../b` are `a/b`, so a file reached beside its
 * includer and again from the search path is recognised as the one file it is.
 *
 * **This is spelling and not identity**, and the difference is a symbolic link
 * or two roots onto the same directory, which this will read twice. `realpath`
 * is the answer to that and is POSIX; a generated compiler is meant to build
 * with `cc file.c` and nothing else, and this file is part of one. The cost of
 * being wrong is a file compiled twice rather than once, which is visible
 * rather than quiet -- it runs twice -- so the trade is the safe way round.
 */
static char *identity_of(Arena *a, const char *path)
{
    size_t n   = strlen(path);
    char  *out = arena_alloc(a, n + 2);
    size_t w   = 0;

    /* Segment by segment, keeping a stack of where each kept one began so
     * that `..` can pop the last. */
    size_t *marks = arena_alloc(a, (n + 2) * sizeof *marks);
    int     nmark = 0;

    size_t i = 0;
    if (path[0] == '/') out[w++] = '/', i = 1;

    while (i < n) {
        size_t start = i;
        while (i < n && path[i] != '/') i++;
        size_t len = i - start;
        while (i < n && path[i] == '/') i++;

        if (len == 0) continue;
        if (len == 1 && path[start] == '.') continue;

        bool up = len == 2 && path[start] == '.' && path[start + 1] == '.';
        if (up && nmark) {
            w = marks[--nmark];          /* the segment before it, undone */
            continue;
        }

        /* A `..` that had nothing to undo stays, and is *not* marked -- or the
         * next one would undo it, and `../../a` would fold to `a`. */
        if (!up) marks[nmark++] = w;
        if (w && out[w - 1] != '/') out[w++] = '/';
        memcpy(out + w, path + start, len);
        w += len;
    }

    if (w == 0) out[w++] = '.';
    out[w] = '\0';
    return out;
}

static bool already_read(const Includer *in, const char *identity)
{
    for (int i = 0; i < in->ndone; i++)
        if (strcmp(in->done[i], identity) == 0) return true;
    return false;
}

static void remember(Includer *in, char *identity)
{
    if (in->ndone == in->capdone) {
        int    cap = in->capdone ? in->capdone * 2 : 8;
        char **big = arena_alloc(in->a, (size_t)cap * sizeof *big);
        memcpy(big, in->done, (size_t)in->ndone * sizeof *big);
        in->done    = big;
        in->capdone = cap;
    }
    in->done[in->ndone++] = identity;
}

/* ------------------------------------------------------------------ */
/* The joined text
 *
 * The same trick `%import` uses one level up: every file's text is held end to
 * end in one buffer so that a position stays a single number, and a map says
 * which file each stretch came from. Everything downstream keeps working with
 * plain offsets and gets the right filename and line for free.
 *
 * The buffer is copied when it grows, and the copies are left behind in the
 * arena rather than freed -- which is what makes it safe for a token read from
 * an earlier revision to still point into it. Text is only ever appended, so
 * an old copy holds the same bytes at the same offsets that the new one does.
 */
static void unit_add(Includer *in, const char *path, size_t start, size_t size)
{
    SourceMap *m = in->map;

    if (m->n == m->cap) {
        int   cap = m->cap ? m->cap * 2 : 8;
        Unit *big = arena_alloc(in->a, (size_t)cap * sizeof *big);
        memcpy(big, m->units, (size_t)m->n * sizeof *big);
        m->units = big;
        m->cap   = cap;
    }
    m->units[m->n++] = (Unit){ .path = path, .start = start, .size = size };
    in->src->map = m;
}

static size_t join(Includer *in, const char *path, const Source *file)
{
    size_t start  = in->src->size;
    size_t need   = start + file->size + 1;
    char  *joined = arena_alloc(in->a, need + 1);

    memcpy(joined, in->src->text, start);
    memcpy(joined + start, file->text, file->size);
    joined[need - 1] = '\n';        /* so the last line of a file ends */
    joined[need]     = '\0';

    in->src->text = joined;
    in->src->size = need;

    unit_add(in, path, start, file->size + 1);
    return start;
}

/* ------------------------------------------------------------------ */
/* The tree */

static bool is_include(const Includer *in, const Value *v)
{
    return v && v->kind == V_NODE && v->type
        && strcmp(v->type, in->g->include_type) == 0;
}

static Value *field_named(const Value *v, const char *field)
{
    if (v->kind != V_NODE || !v->fields) return NULL;
    for (int i = 0; i < v->n; i++)
        if (v->fields[i] && strcmp(v->fields[i], field) == 0) return v->items[i];
    return NULL;
}

/* What an included file contributes to the list the include stood in. */
static bool splice_of(Includer *in, Value *root, const char *path, size_t blame,
                      Value ***items, int *n)
{
    if (root->kind == V_LIST) {
        *items = root->items;
        *n     = root->n;
        return true;
    }
    if (root->kind == V_NODE && root->n == 1 && root->items[0]
        && root->items[0]->kind == V_LIST) {
        *items = root->items[0]->items;
        *n     = root->items[0]->n;
        return true;
    }

    diag_error(in->src, blame, "'%s' has nothing to splice in", path);
    if (root->kind == V_NODE && root->n == 1)
        diag_note("an included file's root has to be a list, or a node holding "
                  "one, and the one thing '%s' holds is %s",
                  root->type, value_kind_name(root->items[0]));
    else if (root->kind == V_NODE)
        diag_note("an included file's root has to be a list, or a node holding "
                  "one, and '%s' holds %d", root->type, root->n);
    else
        diag_note("an included file's root has to be a list, or a node holding "
                  "one, and this one is %s", value_kind_name(root));
    return false;
}

static void expand(Includer *in, Value *v, const char *from);

/* Reads what one include names. Answers false having reported; answers true
 * with `*n` of 0 for a file that has been read already, which is what ends a
 * cycle and what makes two files free to include what each needs. */
static bool read_included(Includer *in, const Value *inc, const char *from,
                          Value ***items, int *n)
{
    *items = NULL;
    *n     = 0;

    Value *named = field_named(inc, in->g->include_field);
    if (!named) {
        diag_error(in->src, inc->pos, "this %s has no '%s' to name a file with",
                   inc->type, in->g->include_field);
        return false;
    }
    if (named->kind != V_TEXT) {
        diag_error(in->src, inc->pos,
                   "the file an include names has to be text, and this is %s",
                   value_kind_name(named));
        return false;
    }

    char *name = arena_strndup(in->a, named->text, named->len);
    if (!*name) {
        diag_error(in->src, inc->pos, "this include names no file");
        return false;
    }

    /* Beside the file the include is *written in*, then the search path, in
     * the order the directories were given. An absolute name searches
     * nothing. */
    Source file;
    char  *path = NULL;

    if (name[0] == '/') {
        path = name;
        if (!source_try(in->a, path, &file)) path = NULL;
    } else {
        path = path_beside(in->a, from, name);
        if (!source_try(in->a, path, &file)) {
            path = NULL;
            for (int i = 0; in->look && i < in->look->n; i++) {
                char *try = path_under(in->a, in->look->dirs[i], name);
                if (source_try(in->a, try, &file)) { path = try; break; }
            }
        }
    }

    if (!path) {
        diag_error(in->src, inc->pos, "cannot read the included file '%s'", name);
        if (name[0] == '/') {
            diag_note("an absolute name is taken as it stands and searches "
                      "nothing");
        } else {
            diag_note("looked beside %s, at %s", from,
                      path_beside(in->a, from, name));
            for (int i = 0; in->look && i < in->look->n; i++)
                diag_note("and at %s", path_under(in->a, in->look->dirs[i], name));
            if (!in->look || !in->look->n)
                diag_note("there is no search path -- `-I dir` adds one");
        }
        return false;
    }

    char *identity = identity_of(in->a, path);
    if (already_read(in, identity)) return true;   /* nothing, and no error */
    remember(in, identity);

    if (in->depth >= INCLUDE_DEPTH) {
        diag_error(in->src, inc->pos, "includes are nested more than %d deep",
                   INCLUDE_DEPTH);
        return false;
    }

    size_t start = join(in, path, &file);

    /* Scanned over the file alone, so that a lexical error in it is reported
     * against its own line; the tokens are then moved into the joined text
     * once, here, and everything the matcher builds is positioned for good. */
    Source alone = { .path = path, .text = in->src->text + start,
                     .size = file.size, .map = NULL };

    Tokens toks;
    if (!lex_run(in->a, in->g, &alone, &toks)) return false;
    for (int i = 0; i < toks.n; i++) toks.items[i].pos += start;

    Value *root = parse_run(in->a, in->g, in->src, &toks);
    if (!root) return false;

    in->depth++;
    expand(in, root, path);
    in->depth--;
    if (!in->ok) return false;

    return splice_of(in, root, path, inc->pos, items, n);
}

/* A list, rebuilt with every include in it opened out. */
static void expand_list(Includer *in, Value *list, const char *from)
{
    int cap = list->n;
    int n   = 0;

    Value **out = arena_alloc(in->a, (size_t)(cap ? cap : 1) * sizeof *out);

    for (int i = 0; i < list->n; i++) {
        Value *item = list->items[i];

        if (is_include(in, item)) {
            Value **spliced;
            int     ns;
            if (!read_included(in, item, from, &spliced, &ns)) {
                in->ok = false;
                continue;
            }
            for (int k = 0; k < ns; k++) {
                if (n == cap) {
                    cap = cap ? cap * 2 : 8;
                    Value **big = arena_alloc(in->a, (size_t)cap * sizeof *big);
                    memcpy(big, out, (size_t)n * sizeof *big);
                    out = big;
                }
                out[n++] = spliced[k];
            }
            continue;
        }

        expand(in, item, from);
        if (n == cap) {
            cap = cap ? cap * 2 : 8;
            Value **big = arena_alloc(in->a, (size_t)cap * sizeof *big);
            memcpy(big, out, (size_t)n * sizeof *big);
            out = big;
        }
        out[n++] = item;
    }

    list->items = out;
    list->n     = n;
}

static void expand(Includer *in, Value *v, const char *from)
{
    if (!v) return;

    if (v->kind == V_LIST) { expand_list(in, v, from); return; }
    if (v->kind != V_NODE) return;

    for (int i = 0; i < v->n; i++) {
        Value *kid = v->items[i];
        if (is_include(in, kid)) {
            /* The one place a splice has no meaning: a field wants one value
             * and a file is a number of them. Solveig refuses the same shape
             * for the same reason -- `x := @include "f"` is a compile error
             * there, and this is that error arriving from the other side. */
            diag_error(in->src, kid->pos,
                       "an include stands here, where one value is wanted");
            diag_note("a file can only be spliced into a list, and '%s' of "
                      "this %s is not one",
                      v->fields && v->fields[i] ? v->fields[i] : "a field",
                      v->type ? v->type : "node");
            in->ok = false;
            continue;
        }
        expand(in, kid, from);
    }
}

/* ------------------------------------------------------------------ */

bool include_expand(Arena *a, const Grammar *g, Source *src,
                    const IncludePath *look, Value *root)
{
    if (!g->include_type || !root) return true;

    SourceMap *map = arena_alloc(a, sizeof *map);
    memset(map, 0, sizeof *map);

    Includer in = { .a = a, .g = g, .src = src, .map = map, .look = look,
                    .ok = true };

    /* The file the command line named is the first unit, and its text is the
     * buffer everything else is appended to -- so every position already
     * worked out for it stays what it was. */
    size_t size   = src->size;
    char  *joined = arena_alloc(a, size + 2);
    memcpy(joined, src->text, size);
    joined[size]     = '\n';
    joined[size + 1] = '\0';

    src->text = joined;
    src->size = size + 1;
    unit_add(&in, src->path, 0, size + 1);

    /* It counts as read, so a file that includes the one that included it, or
     * a library file of its own name, finds it already there and does nothing.
     */
    remember(&in, identity_of(a, src->path));

    /* The one place `expand` cannot look, because it looks *into* things: a
     * file whose whole content is an include has no list around it and nothing
     * to be spliced into. Rare, and silent if it were left. */
    if (is_include(&in, root)) {
        diag_error(src, root->pos,
                   "an include is the whole of this file, and there is nothing "
                   "here for it to be spliced into");
        return false;
    }

    expand(&in, root, src->path);
    return in.ok;
}
