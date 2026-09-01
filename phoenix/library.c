/* library.c -- the functions a pass may call.
 *
 * Deliberately its own file, because the honest risk with a compiler generator
 * is that its library grows without ever being decided about, and a library
 * nobody drew a line around is a language nobody can reimplement. Every entry
 * below is one a pass for the calculator or for Pascal actually needed; the
 * moment one is added for a reason weaker than that, this file is the evidence.
 *
 * An **environment** is an association list -- a list of `[name, value]` pairs,
 * most recent first. `bind` puts a pair on the front, so shadowing is what
 * naturally happens and nobody implemented it. It is linear to look up, which
 * is right for the sizes a compiler description works at and is a thing to
 * revisit with measurements rather than with feelings.
 */
#include "phx.h"

#include <limits.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>

static Value *library_fail(Eval *e, const Expr *x, const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);

    char message[512];
    vsnprintf(message, sizeof message, fmt, ap);
    va_end(ap);

    diag_error(&e->g->src, x->pos, "%s", message);
    return NULL;
}

static bool want(Eval *e, const Expr *x, int n, Value **args)
{
    if (x->nkids == n) return true;

    diag_error(&e->g->src, x->pos, "'%s' takes %d argument%s, and %d %s given",
               x->name, n, n == 1 ? "" : "s", x->nkids,
               x->nkids == 1 ? "was" : "were");
    (void)args;
    return false;
}

static bool text_equal(const Value *a, const Value *b)
{
    return a->kind == V_TEXT && b->kind == V_TEXT
        && a->len == b->len && memcmp(a->text, b->text, a->len) == 0;
}

/* ------------------------------------------------------------------ */

static Value *list_of(Arena *a, Value **items, int n)
{
    Value *v = arena_alloc(a, sizeof *v);
    v->kind  = V_LIST;
    v->items = items;
    v->n     = n;
    return v;
}

static Value *pair(Arena *a, Value *k, Value *v)
{
    Value **items = arena_alloc(a, 2 * sizeof *items);
    items[0] = k;
    items[1] = v;
    return list_of(a, items, 2);
}

/* ------------------------------------------------------------------ */

Value *eval_call(Eval *e, const Expr *x)
{
    Arena *a    = e->a;
    Value *args[4];
    int    argc = x->nkids < 4 ? x->nkids : 4;

    for (int i = 0; i < argc; i++) {
        args[i] = eval_expr(e, x->kids[i]);
        if (!args[i]) return NULL;

        /* A failure passes straight through every function: it has already
         * been reported once, and once is the right number. */
        if (value_failed(args[i])) return args[i];
    }
    const char *f = x->name;

    /* ---- environments ---- */

    if (strcmp(f, "empty") == 0) {
        if (!want(e, x, 0, args)) return NULL;
        return list_of(a, NULL, 0);
    }

    /* `bind` takes a name or a **list** of names, because `var a, b : integer`
     * binds two things to one type and writing that as two calls needs a fold
     * the notation has not got. Binding several is the same operation as
     * binding one, so it is the same function rather than a second. */
    if (strcmp(f, "bind") == 0) {
        if (!want(e, x, 3, args)) return NULL;
        if (args[0]->kind != V_LIST)
            return library_fail(e, x, "'bind' wants an environment, and this is %s",
                        value_kind_name(args[0]));
        if (args[1]->kind != V_TEXT && args[1]->kind != V_LIST)
            return library_fail(e, x, "'bind' wants a name or a list of names, "
                                      "and this is %s", value_kind_name(args[1]));

        int     adding = args[1]->kind == V_LIST ? args[1]->n : 1;
        int     n      = args[0]->n;
        Value **items  = arena_alloc(a, (size_t)(n + adding) * sizeof *items);

        /* As many values as names binds them **pairwise**; one value binds
         * every name to it. Both are the same operation seen from different
         * sides, so both are `bind` rather than one being a second function. */
        bool pairwise = args[1]->kind == V_LIST && args[2]->kind == V_LIST
                        && args[2]->n == adding && adding > 0;

        for (int i = 0; i < adding; i++) {
            Value *name = args[1]->kind == V_LIST ? args[1]->items[i] : args[1];
            if (name->kind != V_TEXT)
                return library_fail(e, x, "'bind' wants text for a name, and one "
                                          "of these is %s", value_kind_name(name));
            items[i] = pair(a, name, pairwise ? args[2]->items[i] : args[2]);
        }
        memcpy(items + adding, args[0]->items, (size_t)n * sizeof *items);
        return list_of(a, items, n + adding);
    }

    /* `lookup(env, name)` and `lookup(env, name, default)` -- the second is
     * the same operation with an answer for absence, and a notation with no
     * conditional needs one. */
    if (strcmp(f, "lookup") == 0 || strcmp(f, "defined") == 0) {
        bool defaulted = strcmp(f, "lookup") == 0 && x->nkids == 3;
        if (!defaulted && !want(e, x, 2, args)) return NULL;
        if (args[0]->kind != V_LIST)
            return library_fail(e, x, "'%s' wants an environment, and this is %s",
                        f, value_kind_name(args[0]));

        bool asking = f[0] == 'd';
        for (int i = 0; i < args[0]->n; i++) {
            const Value *entry = args[0]->items[i];
            if (entry->kind != V_LIST || entry->n != 2) continue;
            if (text_equal(entry->items[0], args[1]))
                return asking ? value_bool(a, true) : entry->items[1];
        }
        if (asking)    return value_bool(a, false);
        if (defaulted) return args[2];
        return value_nil(a);
    }

    /* ---- the other division ----
     *
     * `div` and `mod` are floored, which docs/semantics.md fixes and which is
     * right for Phoenix's own counting. **Target languages disagree with each
     * other about this**, and a pass that models one of them needs to say
     * which: C, Java and Pascal truncate toward zero, so `-7 / 2` is -3 there
     * and -4 here.
     *
     * These earn their place by the rule at the top of this file: without
     * them, an emit pass and an eval pass for the same language quietly
     * disagree about negative division, and the first anybody hears of it is
     * a compiled program answering differently from the interpreted one.
     * There is no way to write truncation in terms of flooring in a notation
     * with no conditional, which is the other half of why these are here. */

    if (strcmp(f, "quotient") == 0 || strcmp(f, "remainder") == 0) {
        if (!want(e, x, 2, args)) return NULL;
        if (args[0]->kind != V_INT || args[1]->kind != V_INT)
            return library_fail(e, x, "'%s' wants two integers, and got %s and %s",
                        f, value_kind_name(args[0]), value_kind_name(args[1]));

        long long n = args[0]->ival, d = args[1]->ival;
        if (d == 0) return library_fail(e, x, "division by zero");
        if (n == LLONG_MIN && d == -1)
            return library_fail(e, x, "this overflows a 64-bit integer");

        return value_int(a, f[0] == 'q' ? n / d : n % d);   /* C truncates */
    }

    /* ---- conversions ---- */

    if (strcmp(f, "int") == 0) {
        if (!want(e, x, 1, args)) return NULL;
        if (args[0]->kind == V_INT) return args[0];
        if (args[0]->kind == V_FLOAT)
            return library_fail(e, x, "'int' does not narrow a float -- "
                              "say floor, ceiling, round or truncate");
        if (args[0]->kind != V_TEXT)
            return library_fail(e, x, "'int' wants text, and this is %s",
                        value_kind_name(args[0]));

        char *end;
        char *copy = arena_strndup(a, args[0]->text, args[0]->len);
        long long n = strtoll(copy, &end, 10);
        if (end == copy || *end)
            return library_fail(e, x, "\"%s\" is not an integer", copy);
        return value_int(a, n);
    }

    if (strcmp(f, "float") == 0) {
        if (!want(e, x, 1, args)) return NULL;
        if (args[0]->kind == V_FLOAT) return args[0];
        if (args[0]->kind == V_INT)   return value_float(a, (double)args[0]->ival);
        if (args[0]->kind != V_TEXT)
            return library_fail(e, x, "'float' wants text or an integer, and this is %s",
                        value_kind_name(args[0]));

        char *end;
        char *copy = arena_strndup(a, args[0]->text, args[0]->len);
        double d = strtod(copy, &end);
        if (end == copy || *end)
            return library_fail(e, x, "\"%s\" is not a number", copy);
        return value_float(a, d);
    }

    if (strcmp(f, "text") == 0) {
        if (!want(e, x, 1, args)) return NULL;
        char  *out;
        size_t len;
        if (!value_format(a, args[0], &out, &len))
            return library_fail(e, x, "a %s has no written form", value_kind_name(args[0]));
        return value_text(a, out, len);
    }

    if (strcmp(f, "floor") == 0 || strcmp(f, "ceiling") == 0
     || strcmp(f, "round") == 0 || strcmp(f, "truncate") == 0) {
        if (!want(e, x, 1, args)) return NULL;
        if (args[0]->kind != V_FLOAT)
            return library_fail(e, x, "'%s' wants a float, and this is %s",
                        f, value_kind_name(args[0]));

        double d = args[0]->real;
        double r = f[0] == 'f' ? __builtin_floor(d)
                 : f[0] == 'c' ? __builtin_ceil(d)
                 : f[0] == 'r' ? __builtin_round(d)
                               : __builtin_trunc(d);

        if (!(r >= -9223372036854775808.0 && r < 9223372036854775808.0))
            return library_fail(e, x, "%g does not fit a 64-bit integer", d);
        return value_int(a, (long long)r);
    }

    /* ---- text and lists ---- */

    if (strcmp(f, "size") == 0) {
        if (!want(e, x, 1, args)) return NULL;
        switch (args[0]->kind) {
        case V_TEXT: return value_int(a, (long long)args[0]->len);
        case V_LIST:
        case V_NODE: return value_int(a, args[0]->n);
        default:
            return library_fail(e, x, "'size' wants text, a list or a node, and this is %s",
                        value_kind_name(args[0]));
        }
    }

    if (strcmp(f, "at") == 0) {
        if (!want(e, x, 2, args)) return NULL;
        if (args[0]->kind != V_LIST)
            return library_fail(e, x, "'at' wants a list, and this is %s",
                        value_kind_name(args[0]));
        if (args[1]->kind != V_INT)
            return library_fail(e, x, "'at' wants an integer index, and this is %s",
                        value_kind_name(args[1]));

        long long i = args[1]->ival;         /* one-based, both ends included */
        if (i < 1 || i > args[0]->n)
            return library_fail(e, x, "at(%lld) of a list of %d", i, args[0]->n);
        return args[0]->items[i - 1];
    }

    /* ---- flatten ----
     *
     * A declaration list is a list of declarations, each naming several
     * things: `var a, b : integer; c : real` is two nodes and three entries.
     * Turning that into one list is a fold, and there is no fold in a notation
     * with no conditional and no recursion -- `[...$vars.entries]` opens one
     * level and leaves a list of lists.
     *
     * It earns its place by the rule at the top of this file: a pass for a
     * real language needed it, and it could not be written in the notation.
     * One level only, because a deeper one would be guessing at what was
     * meant. */
    if (strcmp(f, "flatten") == 0) {
        if (!want(e, x, 1, args)) return NULL;
        if (args[0]->kind != V_LIST)
            return library_fail(e, x, "'flatten' wants a list, and this is %s",
                                value_kind_name(args[0]));

        int total = 0;
        for (int i = 0; i < args[0]->n; i++) {
            const Value *item = args[0]->items[i];
            total += item->kind == V_LIST ? item->n : 1;
        }

        Value **items = arena_alloc(a, (size_t)(total ? total : 1) * sizeof *items);
        int     n     = 0;

        for (int i = 0; i < args[0]->n; i++) {
            Value *item = args[0]->items[i];
            if (item->kind == V_LIST)
                for (int k = 0; k < item->n; k++) items[n++] = item->items[k];
            else
                items[n++] = item;
        }
        return list_of(a, items, n);
    }

    /* ---- each ----
     *
     * A template applied to every element of a list. There is no map in a
     * notation with no lambda, and every declaration list wants one: `var a, b
     * : Flags` is one node naming two things, and C wants `long a[30]` and
     * `long b[30]` written out.
     *
     * The template's `{}` is the element. It is built with `of` like any
     * other, so the parts that do not vary are already in it by the time this
     * is called:
     *
     *     each($names, "{} {}{};" of $type.pre, "{}", $type.post)
     */
    if (strcmp(f, "each") == 0) {
        bool two = x->nkids == 3;
        if (!two && !want(e, x, 2, args)) return NULL;

        Value *template = two ? args[2] : args[1];
        Value *second   = two ? args[1] : NULL;

        if (args[0]->kind != V_LIST || (two && second->kind != V_LIST))
            return library_fail(e, x, "'each' wants a list");
        if (template->kind != V_TEXT)
            return library_fail(e, x, "'each' wants a template, and this is %s",
                                value_kind_name(template));

        /* Two lists **in step**, when two are given: one hole from each, in
         * order. Pairing a call's arguments with the parameters they are for
         * is what wanted it, and it is the same operation as one list with one
         * hole, so it is the same function.
         *
         * A list that runs out contributes nothing rather than being an
         * error -- a call to something this description does not declare has
         * no parameters to pair with, and adding nothing is right. */
        int n = args[0]->n;
        Value **items = arena_alloc(a, (size_t)(n ? n : 1) * sizeof *items);

        for (int i = 0; i < n; i++) {
            char  *pieces[2] = { "", "" };
            size_t lens[2]   = { 0, 0 };

            if (!value_format(a, args[0]->items[i], &pieces[0], &lens[0]))
                return library_fail(e, x, "'each' cannot write a %s",
                                    value_kind_name(args[0]->items[i]));
            if (two && i < second->n
                && !value_format(a, second->items[i], &pieces[1], &lens[1]))
                return library_fail(e, x, "'each' cannot write a %s",
                                    value_kind_name(second->items[i]));

            size_t cap  = template->len + lens[0] + lens[1] + 1;
            char  *buf  = arena_alloc(a, cap + 1);
            size_t used = 0;
            int    hole = 0;

            for (size_t k = 0; k < template->len; k++) {
                char c = template->text[k];
                if (c == '{' && k + 1 < template->len && template->text[k + 1] == '}') {
                    int which = hole < 2 ? hole : 1;
                    memcpy(buf + used, pieces[which], lens[which]);
                    used += lens[which];
                    hole++;
                    k++;
                    continue;
                }
                buf[used++] = c;
            }
            buf[used] = '\0';
            items[i] = value_text(a, buf, used);
        }
        return list_of(a, items, n);
    }

    if (strcmp(f, "join") == 0) {
        if (x->nkids != 1 && x->nkids != 2) {
            diag_error(&e->g->src, x->pos,
                       "'join' takes a list, and optionally what to put between");
            return NULL;
        }
        if (args[0]->kind != V_LIST)
            return library_fail(e, x, "'join' wants a list, and this is %s",
                        value_kind_name(args[0]));

        const char *sep    = "";
        size_t      seplen = 0;
        if (x->nkids == 2) {
            if (args[1]->kind != V_TEXT)
                return library_fail(e, x, "'join' wants text between, and this is %s",
                            value_kind_name(args[1]));
            sep    = args[1]->text;
            seplen = args[1]->len;
        }

        size_t total = 0;
        for (int i = 0; i < args[0]->n; i++) {
            if (value_failed(args[0]->items[i])) return args[0]->items[i];

            char  *piece;
            size_t len;
            if (!value_format(a, args[0]->items[i], &piece, &len))
                return library_fail(e, x, "'join' cannot write a %s",
                            value_kind_name(args[0]->items[i]));
            total += len + (i ? seplen : 0);
        }

        char  *buf  = arena_alloc(a, total + 1);
        size_t used = 0;
        for (int i = 0; i < args[0]->n; i++) {
            if (i) { memcpy(buf + used, sep, seplen); used += seplen; }
            char  *piece;
            size_t len;
            value_format(a, args[0]->items[i], &piece, &len);
            memcpy(buf + used, piece, len);
            used += len;
        }
        buf[used] = '\0';
        return value_text(a, buf, used);
    }

    return library_fail(e, x, "there is no function called '%s'", f);
}
