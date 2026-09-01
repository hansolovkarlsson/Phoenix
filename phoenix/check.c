/* check.c -- what a grammar has to say about itself before it is used.
 *
 * Every check here exists because getting it wrong produces the worst thing
 * this program could do: report a *correct* file as broken. So each one is
 * paid for by a specific way that happens, and each says which.
 */
#include "phx.h"

#include <stdlib.h>
#include <string.h>

typedef struct {
    Grammar *g;
    bool     ok;
} Check;

/* ------------------------------------------------------------------ */
/* Resolving names
 *
 * A name in a rule is an index afterwards, so nothing below has to search. */

static void resolve(Check *c, GNode *n, const Rule *owner)
{
    Grammar *g = c->g;

    if (n->kind == G_NAME) {
        int i = grammar_find(g, n->text, strlen(n->text));
        if (i < 0) {
            diag_error(&g->src, n->pos, "'%s' is not a rule", n->text);
            c->ok = false;
            return;
        }
        if (!g->rules[i].body) {
            diag_error(&g->src, n->pos,
                       "'%s' is named but never defined", n->text);
            c->ok = false;
            return;
        }
        n->ref = i;
        g->rules[i].used = true;

        /* A lexical rule asking for a syntactic one is asking a token to be
         * made out of a phrase, which is backwards. */
        if (owner->lexical && !g->rules[i].lexical) {
            diag_error(&g->src, n->pos,
                       "lexical rule '%s' refers to '%s', which is syntactic",
                       owner->name, g->rules[i].name);
            c->ok = false;
        }
        return;
    }

    /* The three lexical-only forms, refused where there are only tokens. */
    if (!owner->lexical && (n->kind == G_RANGE || n->kind == G_NOT)) {
        diag_error(&g->src, n->pos,
                   "'%s' asks about characters, and rule '%s' is matched over tokens",
                   n->kind == G_RANGE ? ".." : "!", owner->name);
        c->ok = false;
        return;
    }

    for (int i = 0; i < n->nkids; i++)
        resolve(c, n->kids[i], owner);
}

/* ------------------------------------------------------------------ */
/* Nullability
 *
 * Whether a rule can match nothing. Rules refer to each other, so this is a
 * fixed point rather than one walk. It is wanted for the left-recursion check
 * below: in `a = b a`, `a` is only left-recursive if `b` can vanish.
 */

static bool nullable_node(const Grammar *g, const GNode *n)
{
    switch (n->kind) {
    case G_LIT:   return n->len == 0;
    case G_RANGE: return false;
    case G_NOT:   return false;
    case G_OPT:
    case G_REP:   return true;
    case G_NAME:  return n->ref >= 0 && g->rules[n->ref].nullable;
    case G_SEQ:
        for (int i = 0; i < n->nkids; i++)
            if (!nullable_node(g, n->kids[i])) return false;
        return true;
    case G_ALT:
        for (int i = 0; i < n->nkids; i++)
            if (nullable_node(g, n->kids[i])) return true;
        return false;
    }
    return false;
}

static void compute_nullable(Grammar *g)
{
    for (bool changed = true; changed; ) {
        changed = false;
        for (int i = 0; i < g->nrules; i++) {
            Rule *r = &g->rules[i];
            if (!r->body || r->nullable) continue;
            if (nullable_node(g, r->body)) { r->nullable = true; changed = true; }
        }
    }
}

/* ------------------------------------------------------------------ */
/* Left recursion
 *
 * `expression = expression "+" term` is how the older notation writes a
 * repetition, and it is an infinite descent for a matcher that tries the
 * alternatives in order. Nobody writes it in Wirth's notation, since `{ }` is
 * right there -- and everybody writes it in the other one, which is why
 * accepting both dialects made this check worth having.
 *
 * A rule reaches another *leftmost* if it can get there without having
 * consumed anything first. Transitively closing that and looking for a rule
 * that reaches itself is the whole test.
 */

static void leftmost(const Grammar *g, const GNode *n, char *row)
{
    switch (n->kind) {
    case G_NAME:
        if (n->ref >= 0) row[n->ref] = 1;
        return;
    case G_ALT:
        for (int i = 0; i < n->nkids; i++) leftmost(g, n->kids[i], row);
        return;
    case G_SEQ:
        for (int i = 0; i < n->nkids; i++) {
            leftmost(g, n->kids[i], row);
            if (!nullable_node(g, n->kids[i])) break;
        }
        return;
    case G_OPT: case G_REP: case G_NOT:
        leftmost(g, n->kids[0], row);
        return;
    default:
        return;
    }
}

static void check_left_recursion(Check *c)
{
    Grammar *g = c->g;
    int      n = g->nrules;
    if (n == 0) return;

    char *reach = arena_alloc(g->arena, (size_t)n * (size_t)n);
    memset(reach, 0, (size_t)n * (size_t)n);

    for (int i = 0; i < n; i++)
        if (g->rules[i].body) leftmost(g, g->rules[i].body, reach + (size_t)i * n);

    /* Warshall. The grammars this runs on have tens of rules, not thousands. */
    for (int k = 0; k < n; k++)
        for (int i = 0; i < n; i++)
            if (reach[(size_t)i * n + k])
                for (int j = 0; j < n; j++)
                    if (reach[(size_t)k * n + j]) reach[(size_t)i * n + j] = 1;

    for (int i = 0; i < n; i++) {
        if (!reach[(size_t)i * n + i]) continue;
        diag_error(&g->src, g->rules[i].pos,
                   "'%s' is left-recursive, and ordered choice cannot match it",
                   g->rules[i].name);
        diag_note("write the repetition with { } instead: "
                  "`a = b { \"+\" b }` for `a = a \"+\" b | b`");
        c->ok = false;
    }
}

/* ------------------------------------------------------------------ */
/* Alternatives in the wrong order
 *
 * `"<" | "<="` never matches `<=`: ordered choice takes `<`, succeeds, and
 * leaves the `=` for whatever comes next -- so the error surfaces at the token
 * *after* the real one, which is the least helpful place for it.
 *
 * It is only a hazard in the lexical half. Over tokens a `<=` arrives whole,
 * and a rule asking for `"<"` simply does not match it.
 */

static void check_order(Check *c, const Rule *owner, const GNode *n)
{
    if (n->kind == G_ALT && owner->lexical) {
        for (int i = 0; i < n->nkids; i++) {
            const GNode *a = n->kids[i];
            if (a->kind != G_LIT) continue;

            for (int j = i + 1; j < n->nkids; j++) {
                const GNode *b = n->kids[j];
                if (b->kind != G_LIT) continue;

                if (b->len > a->len && memcmp(a->text, b->text, (size_t)a->len) == 0) {
                    diag_warn(&c->g->src, a->pos,
                              "in '%s', \"%s\" comes before \"%s\" and will always "
                              "win -- put the longer one first",
                              owner->name, a->text, b->text);
                }
            }
        }
    }
    for (int i = 0; i < n->nkids; i++) check_order(c, owner, n->kids[i]);
}

/* ------------------------------------------------------------------ */
/* Fragments
 *
 * `letter` and `digit` are lexical rules and are not tokens -- they are what
 * the token rules are written out of. Nothing about their shape says so, and a
 * scanner taking the longest match with ties broken by declaration order will
 * happily return a file as a stream of `letter`, because `letter` is declared
 * before `identifier` and both match `T`.
 *
 * The tell is that nothing in the syntactic half ever asks for one. That is
 * what `%fragment` declares, and this is the warning for having forgotten.
 */

static void mark_used_by(const Grammar *g, const GNode *n, bool from_syntax,
                         char *by_syntax, char *by_lex)
{
    if (n->kind == G_NAME && n->ref >= 0)
        (from_syntax ? by_syntax : by_lex)[n->ref] = 1;

    for (int i = 0; i < n->nkids; i++)
        mark_used_by(g, n->kids[i], from_syntax, by_syntax, by_lex);
}

static void check_fragments(Check *c)
{
    Grammar *g = c->g;
    int      n = g->nrules;
    if (n == 0) return;

    char *by_syntax = arena_alloc(g->arena, (size_t)n);
    char *by_lex    = arena_alloc(g->arena, (size_t)n);
    memset(by_syntax, 0, (size_t)n);
    memset(by_lex,    0, (size_t)n);

    for (int i = 0; i < n; i++)
        if (g->rules[i].body)
            mark_used_by(g, g->rules[i].body, !g->rules[i].lexical, by_syntax, by_lex);

    for (int i = 0; i < n; i++) {
        const Rule *r = &g->rules[i];
        if (!r->lexical || r->fragment || r->skip || !r->body) continue;
        if (by_syntax[i] || !by_lex[i]) continue;

        diag_warn(&g->src, r->pos,
                  "'%s' is used only by other lexical rules and is not a "
                  "%%fragment -- it will be returned as a token of its own",
                  r->name);
        diag_note("add `%%fragment %s` if it is a helper rather than a token", r->name);
    }
}

/* ------------------------------------------------------------------ */
/* Reserved words
 *
 * Every word-shaped literal in the syntactic half is a reserved word, worked
 * out from the grammar rather than declared -- so `begin` cannot arrive as an
 * identifier, and no grammar had to say so.
 */

static bool word_shaped(const GNode *n)
{
    if (n->len == 0) return false;

    char c = n->text[0];
    if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_')) return false;

    for (int i = 1; i < n->len; i++) {
        c = n->text[i];
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
              || (c >= '0' && c <= '9') || c == '_')) return false;
    }
    return true;
}

static void collect_reserved(Grammar *g, const GNode *n, char **words, int *count)
{
    if (n->kind == G_LIT && word_shaped(n)) {
        for (int i = 0; i < *count; i++)
            if (strcmp(words[i], n->text) == 0) goto done;
        words[(*count)++] = n->text;
    }
done:
    for (int i = 0; i < n->nkids; i++)
        collect_reserved(g, n->kids[i], words, count);
}

static void find_reserved(Grammar *g)
{
    int cap = 0;
    for (int i = 0; i < g->nrules; i++) cap += 64;

    char **words = arena_alloc(g->arena, (size_t)(cap + 1) * sizeof *words);
    int    count = 0;

    for (int i = 0; i < g->nrules; i++)
        if (!g->rules[i].lexical && g->rules[i].body)
            collect_reserved(g, g->rules[i].body, words, &count);

    g->reserved  = words;
    g->nreserved = count;
}

/* ------------------------------------------------------------------ */
/* Actions
 *
 * `$3` drifting when a factor is inserted before it is yacc's most famous
 * silent failure: the grammar still builds, and the tree is quietly wrong.
 * Every reference is checked against the alternative it sits in, when the
 * grammar is read.
 *
 * The node vocabulary is gathered at the same time -- the set of node types a
 * grammar can build, and the fields each carries. That is what `--nodes`
 * prints, and it is what stage 2's passes will be written against, so a type
 * built with two different field lists is worth saying now.
 */

static void check_refs(Check *c, const Rule *owner, const GNode *seq, const Expr *x)
{
    Grammar *g = c->g;

    if (x->kind == X_REF) {
        if (x->name) {
            bool found = false;
            for (int i = 0; i < seq->nkids; i++)
                if (seq->kids[i]->label && strcmp(seq->kids[i]->label, x->name) == 0)
                    found = true;
            if (!found) {
                diag_error(&g->src, x->pos,
                           "no factor in this alternative is named '%s'", x->name);
                c->ok = false;
            }
        } else if (x->index > seq->nkids) {
            diag_error(&g->src, x->pos,
                       "$%d, but this alternative of '%s' has %d factor%s",
                       x->index, owner->name, seq->nkids,
                       seq->nkids == 1 ? "" : "s");
            c->ok = false;
        }
    }
    for (int i = 0; i < x->nkids; i++)
        check_refs(c, owner, seq, x->kids[i]);
}

/* The node types a grammar can build. Held as a flat list; a grammar has tens
 * of these, not thousands. */
typedef struct {
    const char  *type;
    char       **fields;
    int          nfields;
    size_t       pos;
} NodeType;

static NodeType *vocabulary;
static int       nvocabulary;

static void note_node_type(Check *c, const Expr *x)
{
    Grammar *g = c->g;

    for (int i = 0; i < nvocabulary; i++) {
        NodeType *known = &vocabulary[i];
        if (strcmp(known->type, x->name) != 0) continue;

        bool same = known->nfields == x->nkids;
        for (int k = 0; same && k < x->nkids; k++)
            if (strcmp(known->fields[k], x->fields[k]) != 0) same = false;

        if (!same) {
            diag_warn(&g->src, x->pos,
                      "'%s' is built here with %d field%s and elsewhere with %d",
                      x->name, x->nkids, x->nkids == 1 ? "" : "s", known->nfields);
            diag_note("a pass keyed on '%s' would have to handle both", x->name);
        }
        return;
    }

    vocabulary = realloc(vocabulary, (size_t)(nvocabulary + 1) * sizeof *vocabulary);
    if (!vocabulary) { fputs("phx: out of memory\n", stderr); exit(2); }

    vocabulary[nvocabulary++] = (NodeType){
        .type = x->name, .fields = x->fields, .nfields = x->nkids, .pos = x->pos
    };
}

static void collect_types(Check *c, const Expr *x)
{
    if (x->kind == X_NODE) note_node_type(c, x);
    for (int i = 0; i < x->nkids; i++) collect_types(c, x->kids[i]);
}

static void check_actions(Check *c, const Rule *owner, const GNode *n)
{
    if (n->kind == G_SEQ && n->action) {
        check_refs(c, owner, n, n->action);
        collect_types(c, n->action);
    }
    for (int i = 0; i < n->nkids; i++) check_actions(c, owner, n->kids[i]);
}

void grammar_nodes(FILE *out, const Grammar *g)
{
    for (int i = 0; i < nvocabulary; i++) {
        const NodeType *t = &vocabulary[i];
        fprintf(out, "%s", t->type);
        if (t->nfields) {
            fputs("(", out);
            for (int k = 0; k < t->nfields; k++)
                fprintf(out, "%s%s", k ? ", " : "", t->fields[k]);
            fputs(")", out);
        }
        fputc('\n', out);
    }
}

/* ------------------------------------------------------------------ */
/* Clauses a pass can never reach
 *
 * Clauses are tried in order and the first match wins, so a general pattern
 * written above a specific one takes every case the specific one was for. The
 * cost of not saying so is high and the symptom is misleading: the clause is
 * simply never run, and the message arrives somewhere else, as a node missing
 * an attribute that a perfectly good clause defines.
 *
 * It is the same hazard as `"<" | "<="` in the lexical half, one level up, and
 * it gets the same treatment -- except that here it is an error rather than a
 * warning, because there is no reading under which it was meant.
 */

static bool subsumes(const Pattern *general, const Pattern *specific)
{
    if (general->kind == P_ANY || general->kind == P_BIND) return true;
    if (general->kind != specific->kind) return false;

    switch (general->kind) {
    case P_TEXT:
        return general->len == specific->len
            && memcmp(general->name, specific->name, (size_t)general->len) == 0;
    case P_INT:
        return general->ival == specific->ival;

    case P_TYPE: {
        if (strcmp(general->name, specific->name) != 0) return false;

        /* Every field the general one tests must be tested at least as
         * loosely by the specific one. A field it does not mention it does
         * not care about, which is what makes `Binary` catch every `Binary`. */
        for (int i = 0; i < general->nkids; i++) {
            const Pattern *mine = NULL;
            for (int k = 0; k < specific->nkids; k++)
                if (strcmp(general->fields[i], specific->fields[k]) == 0)
                    mine = specific->kids[k];

            if (!mine) return false;
            if (!subsumes(general->kids[i], mine)) return false;
        }
        return true;
    }
    default:
        return false;
    }
}

static void describe(char *buf, size_t size, const Pattern *p)
{
    switch (p->kind) {
    case P_ANY:  snprintf(buf, size, "_"); return;
    case P_BIND: snprintf(buf, size, "%s", p->name); return;
    case P_INT:  snprintf(buf, size, "%lld", p->ival); return;
    case P_TEXT: snprintf(buf, size, "\"%.*s\"", p->len, p->name); return;
    case P_TYPE:
        if (!p->nkids) { snprintf(buf, size, "%s", p->name); return; }
        snprintf(buf, size, "%s(%s: ...)", p->name, p->fields[0]);
        return;
    }
}

static void check_reachable(Check *c)
{
    Grammar *g = c->g;

    for (int i = 0; i < g->npasses; i++) {
        const Pass *pass = &g->passes[i];

        for (int b = 1; b < pass->nrules; b++)
            for (int a = 0; a < b; a++) {
                if (!subsumes(pass->rules[a].pattern, pass->rules[b].pattern))
                    continue;

                char above[128], below[128];
                describe(above, sizeof above, pass->rules[a].pattern);
                describe(below, sizeof below, pass->rules[b].pattern);

                diag_error(&g->src, pass->rules[b].pos,
                           "in pass '%s', '%s' can never match -- '%s' above it "
                           "already takes everything it is for",
                           pass->name, below, above);

                if (strcmp(above, below) == 0)
                    diag_note("clauses for one pattern go together in a single "
                              "rule, not in two");
                else
                    diag_note("put the specific pattern above the general one");

                c->ok = false;
                break;
            }
    }
}

/* ------------------------------------------------------------------ */
/* Literals nothing can spell
 *
 * The syntactic half is matched over tokens, so a `","` in it is asking for a
 * token whose text is a comma. If no lexical rule ever produces one, that rule
 * can never match -- and the way it fails is a syntax error on a correct file,
 * pointing at the comma, saying it expected a comma.
 *
 * Every literal is checked against the scanner when the grammar is read, so
 * the message arrives at the grammar rather than at the first file to use it.
 */

static void check_spellable(Check *c, const Rule *owner, const GNode *n)
{
    if (n->kind == G_LIT && n->len > 0
        && !lex_produces(c->g, n->text, (size_t)n->len)) {
        diag_error(&c->g->src, n->pos,
                   "no token rule spells \"%s\", so '%s' can never match",
                   n->text, owner->name);
        c->ok = false;
    }
    for (int i = 0; i < n->nkids; i++) check_spellable(c, owner, n->kids[i]);
}

/* ------------------------------------------------------------------ */

bool grammar_check(Grammar *g)
{
    Check c = { .g = g, .ok = true };

    free(vocabulary);
    vocabulary  = NULL;
    nvocabulary = 0;

    for (int i = 0; i < g->nrules; i++) {
        Rule *r = &g->rules[i];
        if (!r->body) {
            diag_error(&g->src, r->pos,
                       "'%s' is named by a directive but never defined", r->name);
            c.ok = false;
            continue;
        }
        resolve(&c, r->body, r);
    }
    if (!c.ok) return false;

    compute_nullable(g);
    check_left_recursion(&c);
    if (!c.ok) return false;

    for (int i = 0; i < g->nrules; i++)
        if (g->rules[i].body) check_order(&c, &g->rules[i], g->rules[i].body);

    check_fragments(&c);
    find_reserved(g);

    for (int i = 0; i < g->nrules; i++)
        if (g->rules[i].body) check_actions(&c, &g->rules[i], g->rules[i].body);

    check_reachable(&c);

    for (int i = 0; i < g->nrules; i++)
        if (!g->rules[i].lexical && g->rules[i].body)
            check_spellable(&c, &g->rules[i], g->rules[i].body);

    /* A rule nothing reaches is either a leftover or a typo, and both are
     * worth a line. Three kinds of rule are reached without being named, and
     * warning about those would be noise:
     *
     *   the goal rule          -- reached by being the goal
     *   a token rule           -- its tokens are consumed by their spelling,
     *                             so `symbol = ";" | ...` is used by every
     *                             `";"` in the syntactic half and named by none
     *   a %skip rule           -- produced in order to be thrown away
     */
    for (int i = 0; i < g->nrules; i++) {
        const Rule *r = &g->rules[i];
        if (r->used || i == g->start || r->skip || !r->body) continue;
        if (r->lexical && !r->fragment) continue;
        diag_warn(&g->src, r->pos, "nothing uses '%s'", r->name);
    }

    /* A description with no syntactic half is not wrong -- `lib/lexical.phx`
     * is exactly that, and is meant to be imported rather than used. It is
     * only wrong when something asks it to parse a file, which is where the
     * message belongs and where main.c puts it. */
    return c.ok;
}
