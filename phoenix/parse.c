/* parse.c -- tokens to a tree, using the syntactic half of the grammar.
 *
 * **Ordered choice with local backtracking** -- a PEG, not a general parser.
 * `a | b` tries `a`, and tries `b` only if `a` failed. If `a` succeeds and the
 * rule around it fails later, the choice is *not* revisited.
 *
 * That is a real restriction, and it is written here rather than buried,
 * because the failure it produces is a syntax error on a file that is correct.
 * It costs nothing on an LL(1) grammar, which is what Wirth's Pascal is and
 * what almost every published grammar is. It costs something on a grammar with
 * an alternative that is a proper prefix of a later one.
 *
 * When the match fails, the position it got *furthest* is the one worth
 * reporting -- not the position it stopped at. A PEG that fails at the top has
 * usually backtracked a long way from where the real mistake is, and the
 * furthest token it ever reached is very nearly always the place a person
 * would point at.
 */
#include "phx.h"

#include <string.h>

typedef struct {
    Arena         *a;
    const Grammar *g;
    const Source  *src;
    const Tokens  *t;

    long           furthest;      /* the highest token index ever reached   */
    const char   **wanted;        /* what was being asked for there         */
    int            nwanted;
    int            capwanted;
} Parse;

static long match(Parse *p, const GNode *n, long at, PNode *parent);

/* ------------------------------------------------------------------ */

static char lower(char c)
{
    return (c >= 'A' && c <= 'Z') ? (char)(c - 'A' + 'a') : c;
}

static bool same(const Parse *p, const char *a, size_t alen,
                 const char *b, size_t blen)
{
    if (alen != blen) return false;
    if (!p->g->ignorecase) return memcmp(a, b, alen) == 0;
    for (size_t i = 0; i < alen; i++)
        if (lower(a[i]) != lower(b[i])) return false;
    return true;
}

static bool reserved(const Parse *p, const char *text, size_t len)
{
    for (int i = 0; i < p->g->nreserved; i++)
        if (same(p, p->g->reserved[i], strlen(p->g->reserved[i]), text, len))
            return true;
    return false;
}

/* ------------------------------------------------------------------ */
/* Where it got furthest, and what it wanted there */

static void note_want(Parse *p, long at, const char *what)
{
    if (at < p->furthest) return;

    if (at > p->furthest) {
        p->furthest = at;
        p->nwanted  = 0;
    }
    for (int i = 0; i < p->nwanted; i++)
        if (strcmp(p->wanted[i], what) == 0) return;

    if (p->nwanted == p->capwanted) {
        int          cap = p->capwanted ? p->capwanted * 2 : 16;
        const char **big = arena_alloc(p->a, (size_t)cap * sizeof *big);
        memcpy(big, p->wanted, (size_t)p->nwanted * sizeof *big);
        p->wanted    = big;
        p->capwanted = cap;
    }
    p->wanted[p->nwanted++] = what;
}

/* ------------------------------------------------------------------ */
/* The tree */

static PNode *pnode(Parse *p, const char *name, int rule, size_t pos)
{
    PNode *n = arena_alloc(p->a, sizeof *n);
    n->name  = name;
    n->rule  = rule;
    n->pos   = pos;
    return n;
}

static void add_kid(Parse *p, PNode *parent, PNode *kid)
{
    if (!parent) return;

    if (parent->nkids == parent->capkids) {
        int     cap = parent->capkids ? parent->capkids * 2 : 4;
        PNode **big = arena_alloc(p->a, (size_t)cap * sizeof *big);
        memcpy(big, parent->kids, (size_t)parent->nkids * sizeof *big);
        parent->kids    = big;
        parent->capkids = cap;
    }
    parent->kids[parent->nkids++] = kid;
}

/* Backtracking has to undo what a failed attempt added to the tree. The kids
 * array is arena-allocated and only ever grows, so winding the count back is
 * the whole of it. */
static int mark(const PNode *parent)              { return parent ? parent->nkids : 0; }
static void release(PNode *parent, int to)        { if (parent) parent->nkids = to; }

/* ------------------------------------------------------------------ */

static long match(Parse *p, const GNode *n, long at, PNode *parent)
{
    const Token *toks = p->t->items;
    long         end  = p->t->n;

    switch (n->kind) {
    case G_LIT: {
        if (at >= end) { note_want(p, at, n->text); return -1; }
        if (!same(p, toks[at].text, toks[at].len, n->text, (size_t)n->len)) {
            note_want(p, at, n->text);
            return -1;
        }
        PNode *leaf = pnode(p, NULL, -1, toks[at].pos);
        leaf->text  = toks[at].text;
        leaf->len   = toks[at].len;
        add_kid(p, parent, leaf);
        return at + 1;
    }

    case G_NAME: {
        const Rule *r = &p->g->rules[n->ref];

        /* A name that means a lexical rule is a token kind: any token the
         * scanner made with that rule will do. */
        if (r->lexical) {
            if (at >= end || toks[at].kind != n->ref) {
                note_want(p, at, r->name);
                return -1;
            }
            /* ...except a reserved word. `begin` is spelled like an
             * identifier and the scanner cannot tell them apart; the
             * syntactic half is what knows, because it names `begin`
             * somewhere. */
            if (reserved(p, toks[at].text, toks[at].len)) {
                note_want(p, at, r->name);
                return -1;
            }
            PNode *leaf = pnode(p, r->name, n->ref, toks[at].pos);
            leaf->text  = toks[at].text;
            leaf->len   = toks[at].len;
            add_kid(p, parent, leaf);
            return at + 1;
        }

        PNode *node = pnode(p, r->name, n->ref,
                            at < end ? toks[at].pos : p->src->size);
        long got = match(p, r->body, at, node);
        if (got < 0) return -1;

        add_kid(p, parent, node);
        return got;
    }

    case G_SEQ: {
        int keep = mark(parent);
        for (int i = 0; i < n->nkids; i++) {
            at = match(p, n->kids[i], at, parent);
            if (at < 0) { release(parent, keep); return -1; }
        }
        return at;
    }

    case G_ALT:
        for (int i = 0; i < n->nkids; i++) {
            int  keep = mark(parent);
            long got  = match(p, n->kids[i], at, parent);
            if (got >= 0) return got;
            release(parent, keep);
        }
        return -1;

    case G_OPT: {
        int  keep = mark(parent);
        long got  = match(p, n->kids[0], at, parent);
        if (got >= 0) return got;
        release(parent, keep);
        return at;
    }

    case G_REP:
        for (;;) {
            int  keep = mark(parent);
            long got  = match(p, n->kids[0], at, parent);
            if (got < 0)  { release(parent, keep); return at; }
            if (got == at) return at;              /* an empty body */
            at = got;
        }

    case G_RANGE:
    case G_NOT:
        /* check.c refuses these in a syntactic rule, so reaching one here is
         * a defect in Phoenix rather than in the grammar. */
        return -1;
    }
    return -1;
}

/* ------------------------------------------------------------------ */

static void report_failure(Parse *p)
{
    const Tokens *t = p->t;
    size_t where = p->furthest < t->n ? t->items[p->furthest].pos : p->src->size;

    char buf[512];
    size_t used = 0;
    buf[0] = '\0';

    for (int i = 0; i < p->nwanted && used < sizeof buf - 8; i++) {
        const char *sep = i == 0 ? "" : (i == p->nwanted - 1 ? " or " : ", ");
        int wrote = snprintf(buf + used, sizeof buf - used, "%s%s", sep, p->wanted[i]);
        if (wrote < 0) break;
        used += (size_t)wrote;
    }

    if (p->furthest < t->n) {
        const Token *tok = &t->items[p->furthest];
        diag_error(p->src, where, "expected %s, and found \"%.*s\"",
                   p->nwanted ? buf : "something else", (int)tok->len, tok->text);
    } else {
        diag_error(p->src, where, "expected %s, and the file ended",
                   p->nwanted ? buf : "more");
    }
}

PNode *parse_run(Arena *a, const Grammar *g, const Source *src, const Tokens *t)
{
    Parse p = { .a = a, .g = g, .src = src, .t = t, .furthest = 0 };

    const Rule *start = &g->rules[g->start];
    PNode      *root  = pnode(&p, start->name, g->start, 0);

    long got = match(&p, start->body, 0, root);

    if (got < 0) { report_failure(&p); return NULL; }

    if (got < t->n) {
        /* The goal matched, and there is more file. That is a syntax error at
         * the first thing left over, not a success. */
        p.furthest = got;
        report_failure(&p);
        return NULL;
    }
    return root;
}

/* ------------------------------------------------------------------ */
/* Printing a tree */

static void dump(FILE *out, const PNode *n, const char *prefix, bool last, bool root)
{
    if (root) {
        fprintf(out, "%s\n", n->name);
    } else {
        fprintf(out, "%s%s", prefix, last ? "`- " : "|- ");
        if (n->name && n->text)      fprintf(out, "%s \"%.*s\"\n", n->name, (int)n->len, n->text);
        else if (n->text)            fprintf(out, "\"%.*s\"\n", (int)n->len, n->text);
        else                         fprintf(out, "%s\n", n->name);
    }

    char next[512];
    if (root) {
        next[0] = '\0';
    } else {
        snprintf(next, sizeof next, "%s%s", prefix, last ? "   " : "|  ");
    }

    for (int i = 0; i < n->nkids; i++)
        dump(out, n->kids[i], next, i == n->nkids - 1, false);
}

void tree_dump(FILE *out, const PNode *root)
{
    dump(out, root, "", true, true);
}
