/* pass.c -- reading a `%pass` block.
 *
 *     %pass eval
 *       thread env = empty
 *
 *       Number          : val = int($text) .
 *       Binary(op: "+") : val = $left.val + $right.val .
 *       Variable        : val = lookup($env, $name)
 *                       ! lookup($env, $name) = nil
 *                           : "'{}' is not defined" of $name .
 *
 * A clause is a pattern and then some number of items, ending at a `.`:
 *
 *     : attr = expr         computed from this node and its children
 *     : down attr = expr    handed down to this node's children
 *     ! condition : message reported, when the condition holds
 *
 * Clauses are tried **in order and the first match wins**, which is the same
 * discipline the syntactic half's ordered choice uses. One rule about ordering
 * for the whole tool rather than two.
 */
#include "phx.h"
#include "reader.h"

#include <string.h>

#define peek(r)    reader_peek(r)
#define peek2(r)   reader_peek2(r)
#define advance(r) reader_next(r)
#define at(r, k)   reader_at((r), (k))

static bool capitalised(const char *name)
{
    return name[0] >= 'A' && name[0] <= 'Z';
}

static bool is_word(Reader *r, const char *word)
{
    return at(r, T_NAME) && strcmp(peek(r)->text, word) == 0;
}

/* ------------------------------------------------------------------ */
/* Patterns
 *
 * A pattern tests and binds at once. A field written with a value tests it, a
 * field written with a lower-case name binds it, and a field left out is not
 * looked at -- so `Binary(op: "+")` says nothing about `left` and `right`, and
 * matches whatever they are.
 */

static Pattern *pat_new(Reader *r, PKind kind, size_t pos)
{
    Pattern *p = arena_alloc(r->a, sizeof *p);
    p->kind = kind;
    p->pos  = pos;
    return p;
}

static void pat_add(Reader *r, Pattern *parent, const char *field, Pattern *kid)
{
    int       n      = parent->nkids;
    Pattern **kids   = arena_alloc(r->a, (size_t)(n + 1) * sizeof *kids);
    char    **fields = arena_alloc(r->a, (size_t)(n + 1) * sizeof *fields);

    memcpy(kids,   parent->kids,   (size_t)n * sizeof *kids);
    memcpy(fields, parent->fields, (size_t)n * sizeof *fields);

    kids[n]   = kid;
    fields[n] = (char *)field;

    parent->kids   = kids;
    parent->fields = fields;
    parent->nkids  = n + 1;
}

static Pattern *read_pattern(Reader *r)
{
    MToken *t = peek(r);

    switch (t->kind) {
    case T_UNDER:
        advance(r);
        return pat_new(r, P_ANY, t->pos);

    case T_LIT: {
        advance(r);
        Pattern *p = pat_new(r, P_TEXT, t->pos);
        p->name = t->text;
        p->len  = (int)t->len;
        return p;
    }

    case T_NUMBER: {
        advance(r);
        Pattern *p = pat_new(r, P_INT, t->pos);
        p->ival = t->value;
        return p;
    }

    /* `[ a, b ]`, and `[]` for the empty one. Exactly that many: a pattern
     * that matched a *prefix* would be a second rule about lists to know, and
     * every question asked of one so far is about all of it. */
    case T_LBRACK: {
        advance(r);
        Pattern *p = pat_new(r, P_LIST, t->pos);

        while (!at(r, T_RBRACK)) {
            Pattern *kid = read_pattern(r);
            if (!kid) return NULL;
            pat_add(r, p, NULL, kid);

            if (at(r, T_COMMA)) { advance(r); continue; }
            break;
        }
        if (!at(r, T_RBRACK)) {
            diag_error(r->src, peek(r)->pos, "expected ']' or ',' in a list pattern");
            return NULL;
        }
        advance(r);
        return p;
    }

    case T_MINUS: {
        advance(r);
        if (!at(r, T_NUMBER)) {
            diag_error(r->src, t->pos, "expected a number after '-'");
            return NULL;
        }
        MToken *n = advance(r);
        Pattern *p = pat_new(r, P_INT, t->pos);
        p->ival = -n->value;
        return p;
    }

    case T_NAME: {
        advance(r);

        /* `true`, `false` and `nil` are values in an expression and are values
         * here too. Reading them as binders is the sort of thing that matches
         * everything and looks like it worked. */
        if (strcmp(t->text, "true") == 0 || strcmp(t->text, "false") == 0) {
            Pattern *p = pat_new(r, P_BOOL, t->pos);
            p->ival = t->text[0] == 't';
            return p;
        }
        if (strcmp(t->text, "nil") == 0) return pat_new(r, P_NIL, t->pos);

        if (!capitalised(t->text)) {         /* a binder */
            Pattern *p = pat_new(r, P_BIND, t->pos);
            p->name = t->text;
            return p;
        }

        Pattern *p = pat_new(r, P_TYPE, t->pos);
        p->name = t->text;

        if (!at(r, T_LPAREN)) return p;
        advance(r);

        while (!at(r, T_RPAREN)) {
            if (!at(r, T_NAME)) {
                diag_error(r->src, peek(r)->pos, "expected a field name");
                return NULL;
            }
            MToken *field = advance(r);

            if (!at(r, T_COLON)) {
                diag_error(r->src, peek(r)->pos,
                           "expected ':' after the field '%s'", field->text);
                return NULL;
            }
            advance(r);

            Pattern *kid = read_pattern(r);
            if (!kid) return NULL;
            pat_add(r, p, field->text, kid);

            if (at(r, T_COMMA)) { advance(r); continue; }
            break;
        }
        if (!at(r, T_RPAREN)) {
            diag_error(r->src, peek(r)->pos, "expected ')'");
            return NULL;
        }
        advance(r);
        return p;
    }

    default:
        diag_error(r->src, t->pos, "expected a pattern");
        return NULL;
    }
}

/* ------------------------------------------------------------------ */

static void pass_add_rule(Reader *r, Pass *p, PassRule rule)
{
    PassRule *big = arena_alloc(r->a, (size_t)(p->nrules + 1) * sizeof *big);
    memcpy(big, p->rules, (size_t)p->nrules * sizeof *big);
    big[p->nrules] = rule;
    p->rules  = big;
    p->nrules++;
}

static void rule_add_clause(Reader *r, PassRule *rule, Clause c)
{
    Clause *big = arena_alloc(r->a, (size_t)(rule->nclauses + 1) * sizeof *big);
    memcpy(big, rule->clauses, (size_t)rule->nclauses * sizeof *big);
    big[rule->nclauses] = c;
    rule->clauses = big;
    rule->nclauses++;
}

static void pass_add_thread(Reader *r, Pass *p, char *name, Expr *initial)
{
    char **names = arena_alloc(r->a, (size_t)(p->nthreads + 1) * sizeof *names);
    Expr **inits = arena_alloc(r->a, (size_t)(p->nthreads + 1) * sizeof *inits);

    memcpy(names, p->threads, (size_t)p->nthreads * sizeof *names);
    memcpy(inits, p->initial, (size_t)p->nthreads * sizeof *inits);

    names[p->nthreads] = name;
    inits[p->nthreads] = initial;

    p->threads = names;
    p->initial = inits;
    p->nthreads++;
}

static bool is_thread(const Pass *p, const char *name)
{
    for (int i = 0; i < p->nthreads; i++)
        if (strcmp(p->threads[i], name) == 0) return true;
    return false;
}

/* ------------------------------------------------------------------ */

static bool read_one_pass(Reader *r, Pass *p)
{
    for (;;) {
        MToken *t = peek(r);

        if (t->kind == T_EOF || t->kind == T_DIRECTIVE) return true;

        /* `thread env = empty` -- declared before the clauses that update it,
         * so that a clause naming it is recognisably an update rather than a
         * synthesised attribute that happens to share the name. */
        if (is_word(r, "thread")) {
            advance(r);
            if (!at(r, T_NAME)) {
                diag_error(r->src, t->pos, "'thread' wants the name of an attribute");
                return false;
            }
            MToken *name = advance(r);

            Expr *initial = NULL;
            if (at(r, T_DEFSYM)) {
                advance(r);
                initial = read_expr(r);
                if (!initial) return false;
            }
            if (at(r, T_DOT)) advance(r);

            pass_add_thread(r, p, name->text, initial);
            continue;
        }

        PassRule rule = { .pos = t->pos };
        rule.pattern = read_pattern(r);
        if (!rule.pattern) return false;

        if (!at(r, T_COLON) && !at(r, T_BANG)) {
            diag_error(r->src, peek(r)->pos,
                       "expected ':' or '!' after the pattern");
            return false;
        }

        while (at(r, T_COLON) || at(r, T_BANG)) {
            MToken *lead = advance(r);

            if (lead->kind == T_BANG) {
                Clause c = { .kind = C_ERROR, .pos = lead->pos };

                c.when = read_expr(r);
                if (!c.when) return false;

                if (!at(r, T_COLON)) {
                    diag_error(r->src, peek(r)->pos,
                               "expected ':' and then what to report");
                    return false;
                }
                advance(r);

                c.value = read_expr(r);
                if (!c.value) return false;

                rule_add_clause(r, &rule, c);
                continue;
            }

            Clause c = { .kind = C_SYNTH, .pos = lead->pos };

            if (is_word(r, "down")) { advance(r); c.kind = C_DOWN; }

            if (!at(r, T_NAME)) {
                diag_error(r->src, peek(r)->pos, "expected the name of an attribute");
                return false;
            }
            MToken *name = advance(r);
            c.attr = name->text;

            if (!at(r, T_DEFSYM)) {
                diag_error(r->src, peek(r)->pos,
                           "expected '=' after the attribute '%s'", c.attr);
                return false;
            }
            advance(r);

            c.value = read_expr(r);
            if (!c.value) return false;

            if (c.kind == C_SYNTH && is_thread(p, c.attr)) c.kind = C_THREAD;

            rule_add_clause(r, &rule, c);
        }

        if (at(r, T_DOT)) advance(r);
        pass_add_rule(r, p, rule);
    }
}

/* ------------------------------------------------------------------ */
/* `%driver c = typecheck, emit-c -> out .` */

/* ------------------------------------------------------------------ */
/* `%rewrite name strategy` and then `pattern => action .` until the next
 * directive -- the same shape `%pass` has, because it is the same two halves:
 * a pattern that tests and binds, and an expression that builds.
 *
 * The strategy is a word rather than a default, because which one a rewrite
 * wants is a property of the rewrite and getting it wrong is silent: a
 * constant fold written top-down folds the outside of an expression before its
 * inside and stops one level short.
 */
bool read_rewrite(Reader *r, MToken *directive)
{
    Grammar *g = r->g;

    if (!at(r, T_NAME)) {
        diag_error(r->src, directive->pos, "%%rewrite wants a name");
        return false;
    }
    MToken *name = advance(r);

    if (!at(r, T_NAME) || peek(r)->line != directive->line) {
        diag_error(r->src, name->pos,
                   "%%rewrite wants a strategy after '%s'", name->text);
        diag_note("they are bottomup, topdown and innermost");
        return false;
    }
    MToken *how = advance(r);

    RStrategy strategy;
    if      (strcmp(how->text, "bottomup")  == 0) strategy = R_BOTTOMUP;
    else if (strcmp(how->text, "topdown")   == 0) strategy = R_TOPDOWN;
    else if (strcmp(how->text, "innermost") == 0) strategy = R_INNERMOST;
    else {
        diag_error(r->src, how->pos, "there is no strategy called '%s'", how->text);
        diag_note("they are bottomup, topdown and innermost");
        return false;
    }

    if (at(r, T_DOT)) advance(r);

    if (g->nrewrites == g->caprewrites) {
        int      cap = g->caprewrites ? g->caprewrites * 2 : 4;
        Rewrite *big = arena_alloc(r->a, (size_t)cap * sizeof *big);
        memcpy(big, g->rewrites, (size_t)g->nrewrites * sizeof *big);
        g->rewrites    = big;
        g->caprewrites = cap;
    }

    Rewrite *w = &g->rewrites[g->nrewrites++];
    memset(w, 0, sizeof *w);
    w->name = name->text;
    w->how  = strategy;
    w->pos  = name->pos;

    for (;;) {
        MToken *t = peek(r);
        if (t->kind == T_EOF || t->kind == T_DIRECTIVE) return true;

        RewriteRule rule = { .pos = t->pos };
        rule.pattern = read_pattern(r);
        if (!rule.pattern) return false;

        if (!at(r, T_FATARROW)) {
            diag_error(r->src, peek(r)->pos,
                       "expected '=>' and then what this becomes");
            return false;
        }
        advance(r);

        rule.to = read_expr(r);
        if (!rule.to) return false;

        if (at(r, T_DOT)) advance(r);

        if (w->nrules == w->caprules) {
            int          cap = w->caprules ? w->caprules * 2 : 8;
            RewriteRule *big = arena_alloc(r->a, (size_t)cap * sizeof *big);
            memcpy(big, w->rules, (size_t)w->nrules * sizeof *big);
            w->rules    = big;
            w->caprules = cap;
        }
        w->rules[w->nrules++] = rule;
    }
}

bool read_driver(Reader *r, MToken *directive)
{
    Grammar *g = r->g;

    if (!at(r, T_NAME)) {
        diag_error(r->src, directive->pos, "%%driver wants a name");
        return false;
    }
    MToken *name = advance(r);

    if (!at(r, T_DEFSYM)) {
        diag_error(r->src, peek(r)->pos,
                   "expected '=' and then the passes '%s' runs", name->text);
        return false;
    }
    advance(r);

    if (g->ndrivers == g->capdrivers) {
        int     cap = g->capdrivers ? g->capdrivers * 2 : 4;
        Driver *big = arena_alloc(r->a, (size_t)cap * sizeof *big);
        memcpy(big, g->drivers, (size_t)g->ndrivers * sizeof *big);
        g->drivers    = big;
        g->capdrivers = cap;
    }

    Driver *d = &g->drivers[g->ndrivers++];
    memset(d, 0, sizeof *d);
    d->name = name->text;
    d->pos  = name->pos;

    for (;;) {
        if (!at(r, T_NAME)) {
            diag_error(r->src, peek(r)->pos, "expected the name of a pass");
            return false;
        }
        MToken *pass = advance(r);

        char  **names = arena_alloc(r->a, (size_t)(d->npasses + 1) * sizeof *names);
        size_t *where = arena_alloc(r->a, (size_t)(d->npasses + 1) * sizeof *where);
        memcpy(names, d->passes,   (size_t)d->npasses * sizeof *names);
        memcpy(where, d->pass_pos, (size_t)d->npasses * sizeof *where);

        names[d->npasses] = pass->text;
        where[d->npasses] = pass->pos;
        d->passes   = names;
        d->pass_pos = where;
        d->npasses++;

        if (at(r, T_COMMA)) { advance(r); continue; }
        break;
    }

    /* `-> out` names the attribute of the root that is the answer. Without
     * one, running this driver prints nothing and answers with its status. */
    if (at(r, T_ARROW)) {
        advance(r);
        if (!at(r, T_NAME)) {
            diag_error(r->src, peek(r)->pos,
                       "expected the attribute '%s' answers with", d->name);
            return false;
        }
        d->answer = advance(r)->text;
    }

    if (at(r, T_DOT)) advance(r);
    return true;
}

bool read_passes(Reader *r, MToken *directive)
{
    Grammar *g = r->g;

    if (!at(r, T_NAME)) {
        diag_error(r->src, directive->pos, "%%pass wants a name");
        return false;
    }
    MToken *name = advance(r);

    if (g->npasses == g->cappasses) {
        int   cap = g->cappasses ? g->cappasses * 2 : 8;
        Pass *big = arena_alloc(r->a, (size_t)cap * sizeof *big);
        memcpy(big, g->passes, (size_t)g->npasses * sizeof *big);
        g->passes    = big;
        g->cappasses = cap;
    }

    Pass *p = &g->passes[g->npasses++];
    memset(p, 0, sizeof *p);
    p->name = name->text;
    p->pos  = name->pos;

    return read_one_pass(r, p);
}
