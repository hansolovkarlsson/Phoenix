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
 *
 * ---------------------------------------------------------------------------
 * What a match produces
 *
 * Matching appends **values** to a list belonging to the enclosing sequence.
 * A literal or a token appends one. A rule appends whatever its body answered.
 * A sequence carrying an action gathers its factors, evaluates the action, and
 * appends the single value that came out.
 *
 * A rule's answer follows one rule with no exceptions: **a body that produced
 * one value answers that value; a body that produced any other number answers
 * a node named after the rule, holding them.** So a chain of rules that each
 * pass one thing along collapses to the thing, and the interior nodes a
 * hand-written tree-builder exists to strip are never built at all.
 */
#include "phx.h"

#include <string.h>

/* A growable list of values -- one per sequence being matched. */
typedef struct {
    Value **items;
    int     n;
    int     cap;
} Slots;

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

static long match(Parse *p, const GNode *n, long at, Slots *out);

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
/* Values */

static Value *value_new(Parse *p, VKind kind, size_t pos)
{
    Value *v = arena_alloc(p->a, sizeof *v);
    v->kind  = kind;
    v->pos   = pos;
    return v;
}

static Value *token_value(Parse *p, const Token *tok)
{
    Value *v = value_new(p, V_TOKEN, tok->pos);
    v->text  = tok->text;
    v->len   = tok->len;
    return v;
}

static void slots_add(Parse *p, Slots *s, Value *v)
{
    if (s->n == s->cap) {
        int     cap = s->cap ? s->cap * 2 : 8;
        Value **big = arena_alloc(p->a, (size_t)cap * sizeof *big);
        memcpy(big, s->items, (size_t)s->n * sizeof *big);
        s->items = big;
        s->cap   = cap;
    }
    s->items[s->n++] = v;
}

/* Several values become one: a lone value passes through, anything else is
 * gathered into a list. This is the rule the header states, and the only place
 * it is decided. */
static Value *one_of(Parse *p, Slots *s, size_t pos)
{
    if (s->n == 1) return s->items[0];

    Value *v = value_new(p, V_LIST, pos);
    v->items = s->items;
    v->n     = s->n;
    return v;
}

/* ------------------------------------------------------------------ */
/* Evaluating an action
 *
 * `slots` holds one value per factor of the sequence, and `acc` is what the
 * enclosing sequence has built so far -- the `$$` a fold is written with.
 */

typedef struct {
    Parse       *p;
    const GNode *seq;      /* the sequence being built, for its labels    */
    Slots       *slots;
    Value       *acc;
} Build;

static Value *evaluate(Build *b, const Expr *x);

/* How many values a list expression will have, once spreads are opened out. */
static int list_size(Build *b, const Expr *x)
{
    int n = 0;
    for (int i = 0; i < x->nkids; i++) {
        const Expr *item = x->kids[i];
        if (item->kind != X_SPREAD) { n++; continue; }

        Value *v = evaluate(b, item->kids[0]);
        n += (v && v->kind == V_LIST) ? v->n : 1;
    }
    return n;
}

static Value *evaluate(Build *b, const Expr *x)
{
    Parse *p = b->p;

    switch (x->kind) {
    case X_ACC:
        if (!b->acc) {
            diag_error(&p->g->src, x->pos,
                       "$$ is nothing here -- there is no value before this one");
            return NULL;
        }
        return b->acc;

    case X_REF: {
        int index = x->index;

        if (x->name) {                              /* by label */
            index = 0;
            for (int i = 0; i < b->seq->nkids; i++)
                if (b->seq->kids[i]->label
                    && strcmp(b->seq->kids[i]->label, x->name) == 0) {
                    index = i + 1;
                    break;
                }
            if (!index) {
                diag_error(&p->g->src, x->pos,
                           "no factor here is named '%s'", x->name);
                return NULL;
            }
        }
        if (index > b->slots->n) {
            diag_error(&p->g->src, x->pos,
                       "$%d, but this alternative has %d factor%s",
                       index, b->slots->n, b->slots->n == 1 ? "" : "s");
            return NULL;
        }
        return b->slots->items[index - 1];
    }

    case X_TEXT: {
        Value *v = value_new(p, V_TOKEN, x->pos);
        v->text  = x->name;
        v->len   = (size_t)x->len;
        return v;
    }

    case X_LIST: {
        Value  *v     = value_new(p, V_LIST, x->pos);
        int     size  = list_size(b, x);
        Value **items = arena_alloc(p->a, (size_t)(size ? size : 1) * sizeof *items);
        int     n     = 0;

        for (int i = 0; i < x->nkids; i++) {
            const Expr *item = x->kids[i];

            if (item->kind == X_SPREAD) {
                Value *inner = evaluate(b, item->kids[0]);
                if (!inner) return NULL;
                if (inner->kind == V_LIST)
                    for (int k = 0; k < inner->n; k++) items[n++] = inner->items[k];
                else
                    items[n++] = inner;
                continue;
            }
            Value *got = evaluate(b, item);
            if (!got) return NULL;
            items[n++] = got;
        }
        v->items = items;
        v->n     = n;
        return v;
    }

    case X_NODE: {
        Value *v = value_new(p, V_NODE, x->pos);
        v->type  = x->name;

        if (x->nkids == 0) return v;

        v->items  = arena_alloc(p->a, (size_t)x->nkids * sizeof *v->items);
        v->fields = arena_alloc(p->a, (size_t)x->nkids * sizeof *v->fields);

        for (int i = 0; i < x->nkids; i++) {
            Value *got = evaluate(b, x->kids[i]);
            if (!got) return NULL;
            v->items[i]  = got;
            v->fields[i] = x->fields[i];
        }
        v->n = x->nkids;
        return v;
    }

    case X_SPREAD:
        diag_error(&p->g->src, x->pos, "'...' belongs inside a list");
        return NULL;
    }
    return NULL;
}

/* Whether an action mentions `$$`, and so folds rather than appends. */
static bool folds(const Expr *x)
{
    if (!x) return false;
    if (x->kind == X_ACC) return true;
    for (int i = 0; i < x->nkids; i++)
        if (folds(x->kids[i])) return true;
    return false;
}

/* ------------------------------------------------------------------ */

/* A sequence carrying an action: each factor gets a slot of its own, so that
 * `$2` means the second factor and not the second value -- a `{ }` producing
 * three things still occupies one position. */
static long match_action_seq(Parse *p, const GNode *n, long at, Slots *out)
{
    Slots *slots = arena_alloc(p->a, (size_t)(n->nkids ? n->nkids : 1) * sizeof *slots);
    memset(slots, 0, (size_t)(n->nkids ? n->nkids : 1) * sizeof *slots);

    Slots gathered = { 0 };
    size_t pos = at < p->t->n ? p->t->items[at].pos : p->src->size;

    for (int i = 0; i < n->nkids; i++) {
        at = match(p, n->kids[i], at, &slots[i]);
        if (at < 0) return -1;
        slots_add(p, &gathered, one_of(p, &slots[i], pos));
    }

    Build b = { .p = p, .seq = n, .slots = &gathered, .acc = NULL };

    /* `$$` is the value the enclosing sequence built last, and the result
     * takes its place rather than following it. That is the whole of a left
     * fold, and it is why the flat repetition a grammar writes for a binary
     * operator comes out as the tree it means. */
    bool fold = folds(n->action);
    if (fold) {
        if (out->n == 0) {
            diag_error(&p->g->src, n->action->pos,
                       "$$ is nothing here -- there is no value before this one");
            return -1;
        }
        b.acc = out->items[out->n - 1];
    }

    Value *built = evaluate(&b, n->action);
    if (!built) return -1;

    if (fold) out->items[out->n - 1] = built;
    else      slots_add(p, out, built);

    return at;
}

static long match(Parse *p, const GNode *n, long at, Slots *out)
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
        slots_add(p, out, token_value(p, &toks[at]));
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
            slots_add(p, out, token_value(p, &toks[at]));
            return at + 1;
        }

        Slots  inner = { 0 };
        size_t pos   = at < end ? toks[at].pos : p->src->size;

        long got = match(p, r->body, at, &inner);
        if (got < 0) return -1;

        Value *v = inner.n == 1 ? inner.items[0] : NULL;
        if (!v) {
            v        = value_new(p, V_NODE, pos);
            v->type  = r->name;
            v->items = inner.items;
            v->n     = inner.n;
        }
        slots_add(p, out, v);
        return got;
    }

    case G_SEQ: {
        if (n->action) return match_action_seq(p, n, at, out);

        int keep = out->n;
        for (int i = 0; i < n->nkids; i++) {
            at = match(p, n->kids[i], at, out);
            if (at < 0) { out->n = keep; return -1; }
        }
        return at;
    }

    case G_ALT:
        for (int i = 0; i < n->nkids; i++) {
            int  keep = out->n;
            long got  = match(p, n->kids[i], at, out);
            if (got >= 0) return got;
            out->n = keep;
        }
        return -1;

    case G_OPT: {
        int  keep = out->n;
        long got  = match(p, n->kids[0], at, out);
        if (got >= 0) return got;
        out->n = keep;
        return at;
    }

    case G_REP:
        for (;;) {
            int  keep = out->n;
            long got  = match(p, n->kids[0], at, out);
            if (got < 0)  { out->n = keep; return at; }
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

    char   buf[512];
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

Value *parse_run(Arena *a, const Grammar *g, const Source *src, const Tokens *t)
{
    Parse p = { .a = a, .g = g, .src = src, .t = t, .furthest = 0 };

    const Rule *start = &g->rules[g->start];
    Slots       out   = { 0 };

    long got = match(&p, start->body, 0, &out);
    if (got < 0)      { report_failure(&p); return NULL; }
    if (diag_failed()) return NULL;          /* an action went wrong */

    if (got < t->n) {
        /* The goal matched, and there is more file. That is a syntax error at
         * the first thing left over, not a success. */
        p.furthest = got;
        report_failure(&p);
        return NULL;
    }

    if (out.n == 1) return out.items[0];

    Value *root = value_new(&p, V_NODE, 0);
    root->type  = start->name;
    root->items = out.items;
    root->n     = out.n;
    return root;
}

/* ------------------------------------------------------------------ */
/* Printing a tree */

static void dump(FILE *out, const Value *v, const char *prefix, bool last,
                 const char *field, bool root)
{
    char here[512];

    if (root) {
        here[0] = '\0';
    } else {
        fprintf(out, "%s%s", prefix, last ? "`- " : "|- ");
        if (field) fprintf(out, "%s: ", field);
        snprintf(here, sizeof here, "%s%s", prefix, last ? "   " : "|  ");
    }

    switch (v->kind) {
    case V_TOKEN:
        fprintf(out, "\"%.*s\"\n", (int)v->len, v->text);
        return;
    case V_NODE:
        fprintf(out, "%s\n", v->type);
        break;
    case V_LIST:
        fprintf(out, "[%d]\n", v->n);
        break;
    }

    for (int i = 0; i < v->n; i++)
        dump(out, v->items[i], here, i == v->n - 1,
             v->fields ? v->fields[i] : NULL, false);
}

void tree_dump(FILE *out, const Value *root)
{
    switch (root->kind) {
    case V_TOKEN: fprintf(out, "\"%.*s\"\n", (int)root->len, root->text); return;
    case V_NODE:  fprintf(out, "%s\n", root->type); break;
    case V_LIST:  fprintf(out, "[%d]\n", root->n);  break;
    }
    for (int i = 0; i < root->n; i++)
        dump(out, root->items[i], "", i == root->n - 1,
             root->fields ? root->fields[i] : NULL, false);
}
