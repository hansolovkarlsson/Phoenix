/* lex.c -- characters to tokens, using the lexical half of the grammar.
 *
 * The rule is the one every lexer has: at each position, try every token rule
 * and take the **longest** lex_match. Ties go to the rule declared first.
 *
 * That is deliberately not the ordered choice the syntactic half uses, and the
 * difference is the reason `"<" | "<="` is a question there and not here. A
 * scanner that took the first lex_match would have to be told, by ordering, that
 * `<=` is longer than `<`. One that takes the longest already knows.
 *
 * Within a single rule, though, the alternatives *are* ordered -- `a | b`
 * tries `a` first -- so a rule that gathers punctuation still has to put the
 * two-character symbols before the one-character ones. check.c warns when it
 * does not.
 */
#include "phx.h"

#include <string.h>

typedef struct {
    const Grammar *g;
    const Source  *src;
} Lex;

static long lex_match(Lex *l, const GNode *n, long pos);

static char lex_lower(char c)
{
    return (c >= 'A' && c <= 'Z') ? (char)(c - 'A' + 'a') : c;
}

static bool lex_same(const Lex *l, const char *a, const char *b, size_t len)
{
    if (!l->g->ignorecase) return memcmp(a, b, len) == 0;
    for (size_t i = 0; i < len; i++)
        if (lex_lower(a[i]) != lex_lower(b[i])) return false;
    return true;
}

/* Answers where the lex_match ended, or -1. */
static long lex_match(Lex *l, const GNode *n, long pos)
{
    const char *s    = l->src->text;
    long        size = (long)l->src->size;

    switch (n->kind) {
    case G_LIT:
        if (pos + n->len > size) return -1;
        return lex_same(l, s + pos, n->text, (size_t)n->len) ? pos + n->len : -1;

    case G_RANGE: {
        if (pos >= size) return -1;
        char c  = s[pos];
        char lo = n->text[0], hi = n->upto[0];
        if (l->g->ignorecase) { c = lex_lower(c); lo = lex_lower(lo); hi = lex_lower(hi); }
        return (c >= lo && c <= hi) ? pos + 1 : -1;
    }

    case G_NAME:
        return lex_match(l, l->g->rules[n->ref].body, pos);

    case G_SEQ:
        for (int i = 0; i < n->nkids; i++) {
            pos = lex_match(l, n->kids[i], pos);
            if (pos < 0) return -1;
        }
        return pos;

    case G_ALT:
        for (int i = 0; i < n->nkids; i++) {
            long got = lex_match(l, n->kids[i], pos);
            if (got >= 0) return got;
        }
        return -1;

    case G_OPT: {
        long got = lex_match(l, n->kids[0], pos);
        return got >= 0 ? got : pos;
    }

    case G_REP:
        for (;;) {
            long got = lex_match(l, n->kids[0], pos);
            if (got < 0) return pos;
            if (got == pos) return pos;      /* an empty body would spin here */
            pos = got;
        }

    case G_NOT:
        /* One character, provided the inner factor does not lex_match here. It is
         * PEG's negative lookahead with a character taken after it, which is
         * the only form anybody writes: `"{" { ! "}" } "}"` is a comment. */
        if (pos >= size) return -1;
        return lex_match(l, n->kids[0], pos) >= 0 ? -1 : pos + 1;
    }
    return -1;
}

static void push(Arena *a, Tokens *t, Token tok)
{
    if (t->n == t->cap) {
        int    cap = t->cap ? t->cap * 2 : 512;
        Token *big = arena_alloc(a, (size_t)cap * sizeof *big);
        memcpy(big, t->items, (size_t)t->n * sizeof *big);
        t->items = big;
        t->cap   = cap;
    }
    t->items[t->n++] = tok;
}

/* How many unmatched characters are worth reporting before the file is
 * plainly not the language it was said to be. */
#define MAX_BAD 20

bool lex_run(Arena *a, const Grammar *g, const Source *src, Tokens *out)
{
    Lex  l   = { .g = g, .src = src };
    long pos = 0;
    int  bad = 0;

    memset(out, 0, sizeof *out);

    while (pos < (long)src->size) {
        long best     = -1;
        int  best_rule = -1;

        for (int i = 0; i < g->nrules; i++) {
            const Rule *r = &g->rules[i];
            if (!r->lexical || r->fragment || !r->body) continue;

            long got = lex_match(&l, r->body, pos);

            /* A zero-length lex_match is not a token; it would leave the scanner
             * exactly where it was, forever. */
            if (got > pos && got > best) { best = got; best_rule = i; }
        }

        if (best_rule < 0) {
            /* Take the character and carry on, rather than stopping. A scan
             * that halts at the first character it cannot read tells you the
             * least about the file you know the least about -- two stray
             * characters on two lines should produce two messages, not one
             * message and a mystery. */
            if (++bad <= MAX_BAD)
                diag_error(src, (size_t)pos, "nothing here matches any token rule");
            if (bad == MAX_BAD + 1)
                diag_note("%d unreadable characters so far; not listing the rest",
                          bad);
            pos++;
            continue;
        }

        if (!g->rules[best_rule].skip)
            push(a, out, (Token){ .kind = best_rule,
                                  .text = src->text + pos,
                                  .len  = (size_t)(best - pos),
                                  .pos  = (size_t)pos });
        pos = best;
    }
    return bad == 0;
}

bool lex_produces(const Grammar *g, const char *text, size_t len)
{
    Source one = { .path = "", .text = (char *)text, .size = len };
    Lex    l   = { .g = g, .src = &one };

    for (int i = 0; i < g->nrules; i++) {
        const Rule *r = &g->rules[i];
        if (!r->lexical || r->fragment || r->skip || !r->body) continue;

        /* The whole of it, and as one token. A rule matching just the `:` of
         * a `:=` has not produced the literal the syntactic half asked for. */
        if (lex_match(&l, r->body, 0) == (long)len) return true;
    }
    return false;
}

void tokens_dump(FILE *out, const Grammar *g, const Source *src, const Tokens *t)
{
    for (int i = 0; i < t->n; i++) {
        const Token *tok = &t->items[i];
        int line, col;
        source_position(src, tok->pos, &line, &col);
        fprintf(out, "%4d:%-3d  %-18s %.*s\n",
                line, col, g->rules[tok->kind].name, (int)tok->len, tok->text);
    }
}
