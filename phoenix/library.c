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



/* ------------------------------------------------------------------ */

static Value *list_of(Arena *a, Value **items, int n)
{
    Value *v = arena_alloc(a, sizeof *v);
    v->kind  = V_LIST;
    v->items = items;
    v->n     = n;
    return v;
}

/* One number as `width` little-endian bytes. Split out when `bytes` learned to
 * take a list, so that one number and a column of them cannot disagree. */
static Value *bytes_of(Eval *e, const Expr *x, Arena *a, const Value *n,
                       long long width)
{
    if (n->kind != V_INT && n->kind != V_FLOAT)
        return library_fail(e, x, "'bytes' wants a number, and this is %s",
                            value_kind_name(n));

    /* A float is written as what it *is* -- its IEEE 754 bits -- which is
     * the only reading of "this number as eight bytes" a binary format
     * ever wants. Four bytes is single precision, and narrower is not a
     * float at all, so it is refused rather than quietly rounded. */
    unsigned long long v;
    if (n->kind == V_FLOAT) {
        if (width == 8) {
            double d = n->real;
            unsigned long long bits;
            memcpy(&bits, &d, sizeof bits);
            v = bits;
        } else if (width == 4) {
            float g = (float)n->real;
            unsigned int bits;
            memcpy(&bits, &g, sizeof bits);
            v = bits;
        } else {
            return library_fail(e, x, "a float is four or eight bytes, not %lld",
                                width);
        }
    } else {
        v = (unsigned long long)n->ival;
    }

    char *out = arena_alloc(a, (size_t)width + 1);
    for (long long i = 0; i < width; i++) out[i] = (char)((v >> (8 * i)) & 0xff);
    out[width] = '\0';

    return value_text(a, out, (size_t)width);
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

    /* `positions(list)` -- the table saying where each thing is, which is the
     * one fact about a list nothing else could reach: `at` wants an index and
     * nothing produced one. It is what turns a list of names into slots.
     *
     * Written as a table rather than as a list of indices so that it composes
     * with `lookup`, which is how every other question in the notation is
     * asked. A repeated element keeps its **first** position, matching what
     * `lookup` would answer for it. */
    if (strcmp(f, "positions") == 0) {
        if (!want(e, x, 1, args)) return NULL;
        if (args[0]->kind != V_LIST)
            return library_fail(e, x, "'positions' wants a list, and this is %s",
                                value_kind_name(args[0]));

        Value **items = arena_alloc(a, (size_t)args[0]->n * sizeof *items);
        int     n     = 0;

        for (int i = 0; i < args[0]->n; i++) {
            bool seen = false;
            for (int j = 0; j < n; j++)
                if (value_equal(items[j]->items[0], args[0]->items[i])) { seen = true; break; }
            if (seen) continue;
            items[n++] = pair(a, args[0]->items[i], value_int(a, i));
        }
        return list_of(a, items, n);
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
            /* Compared the way `=` compares, not as text only. Text-only
             * meant an integer key never matched and never said so:
             * `lookup([[1, "char"]], size(t), "string")` quietly answered
             * "string" for every length. */
            if (value_equal(entry->items[0], args[1]))
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

    /* `int(text)` and `int(text, base)` -- the same operation with the base
     * said out loud, which a language whose literals carry a marker needs:
     * Solveig writes `#45`, `$ff` and `%1010` and they are one node. */
    if (strcmp(f, "int") == 0) {
        bool based = x->nkids == 2;
        if (!based && !want(e, x, 1, args)) return NULL;
        if (args[0]->kind == V_INT) return args[0];
        if (args[0]->kind == V_FLOAT)
            return library_fail(e, x, "'int' does not narrow a float -- "
                              "say floor, ceiling, round or truncate");
        if (args[0]->kind != V_TEXT)
            return library_fail(e, x, "'int' wants text, and this is %s",
                        value_kind_name(args[0]));

        int base = 10;
        if (based) {
            if (args[1]->kind != V_INT || args[1]->ival < 2 || args[1]->ival > 36)
                return library_fail(e, x, "'int' wants a base between 2 and 36");
            base = (int)args[1]->ival;
        }

        char *end;
        char *copy = arena_strndup(a, args[0]->text, args[0]->len);
        long long n = strtoll(copy, &end, base);
        if (end == copy || *end)
            return library_fail(e, x, "\"%s\" is not an integer in base %d",
                                copy, base);
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

    /* ---- bytes ----
     *
     * An integer as that many bytes, least significant first. **A description
     * that emits a binary format cannot do without it**, and it cannot be
     * written in the notation: there is no way to take a value apart into
     * bytes with arithmetic that answers integers and text that answers
     * characters.
     *
     * Little-endian and a width, because those are the two things a file
     * format fixes and the two things a caller must therefore say.
     *
     * A **list** of numbers answers a list of encodings, which is what a table
     * in a binary format is a column of.
     */
    if (strcmp(f, "bytes") == 0) {
        if (!want(e, x, 2, args)) return NULL;
        if (args[1]->kind != V_INT)
            return library_fail(e, x, "'bytes' wants a number and a width");

        long long width = args[1]->ival;
        if (width < 1 || width > 8)
            return library_fail(e, x, "'bytes' writes one to eight bytes, not %lld",
                                width);

        /* **A list of numbers answers a list of encodings**, which is the same
         * operation done as many times and not a second function. A table in a
         * binary format is a column of fixed-width numbers, and a description
         * that can say what the numbers are had no way to say them as bytes --
         * the row-by-row alternative is a clause on every node type that could
         * be a row, which is the same line of notation written twelve times.
         *
         * A *list* rather than the bytes joined together, because `join` is how
         * this notation concatenates and `each` is how it pairs two columns up.
         * Answering the concatenation would have been one function doing two
         * things. */
        if (args[0]->kind == V_LIST) {
            Value **items = arena_alloc(a, (size_t)(args[0]->n ? args[0]->n : 1)
                                             * sizeof *items);
            for (int i = 0; i < args[0]->n; i++) {
                if (value_failed(args[0]->items[i])) return args[0]->items[i];
                Value *one = bytes_of(e, x, a, args[0]->items[i], width);
                if (!one) return NULL;
                items[i] = one;
            }
            return list_of(a, items, args[0]->n);
        }
        return bytes_of(e, x, a, args[0], width);
    }

    /* ---- text ----
     *
     * Ordinary operations on bytes, and their absence was a real gap: a
     * Pascal string literal arrives with its quotes on and its doubled quotes
     * undoubled, and turning `'it''s'` into `"it's"` is
     * `join(split(slice(t, 2, size(t) - 1), "''"), "'")` and cannot be written
     * any other way here. One-based, both ends included, as everything in
     * this notation is. */

    if (strcmp(f, "slice") == 0) {
        if (!want(e, x, 3, args)) return NULL;
        if (args[0]->kind != V_TEXT)
            return library_fail(e, x, "'slice' wants text, and this is %s",
                                value_kind_name(args[0]));
        if (args[1]->kind != V_INT || args[2]->kind != V_INT)
            return library_fail(e, x, "'slice' wants two integers");

        long long from = args[1]->ival, to = args[2]->ival;
        if (from < 1) from = 1;
        if (to > (long long)args[0]->len) to = (long long)args[0]->len;
        if (to < from) return value_text(a, "", 0);

        return value_text(a, args[0]->text + (from - 1), (size_t)(to - from + 1));
    }

    if (strcmp(f, "split") == 0) {
        if (!want(e, x, 2, args)) return NULL;
        if (args[0]->kind != V_TEXT || args[1]->kind != V_TEXT)
            return library_fail(e, x, "'split' wants text and text");
        if (args[1]->len == 0)
            return library_fail(e, x, "'split' cannot split on nothing");

        int cap = 8, n = 0;
        Value **items = arena_alloc(a, (size_t)cap * sizeof *items);

        size_t start = 0;
        for (size_t i = 0; i + args[1]->len <= args[0]->len; ) {
            if (memcmp(args[0]->text + i, args[1]->text, args[1]->len) != 0) {
                i++;
                continue;
            }
            if (n == cap) {
                cap *= 2;
                Value **big = arena_alloc(a, (size_t)cap * sizeof *big);
                memcpy(big, items, (size_t)n * sizeof *big);
                items = big;
            }
            items[n++] = value_text(a, args[0]->text + start, i - start);
            i += args[1]->len;
            start = i;
        }
        if (n == cap) {
            Value **big = arena_alloc(a, (size_t)(cap + 1) * sizeof *big);
            memcpy(big, items, (size_t)n * sizeof *big);
            items = big;
        }
        items[n++] = value_text(a, args[0]->text + start, args[0]->len - start);
        return list_of(a, items, n);
    }

    /* ---- lists ---- */

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

    /* `sizes(list)` -- how big each element is, which is the companion to
     * `positions(list)`: that one answers where each thing is and this one how
     * big it is, and neither can be asked any other way. `each` applies a
     * *template* to a list, and a template can only write an element out.
     *
     * A table in a binary format is a column of lengths beside a column of
     * things, and the alternative to this was the same line of notation once
     * per node type that could be a row. */
    if (strcmp(f, "sizes") == 0) {
        if (!want(e, x, 1, args)) return NULL;
        if (args[0]->kind != V_LIST)
            return library_fail(e, x, "'sizes' wants a list, and this is %s",
                                value_kind_name(args[0]));

        Value **items = arena_alloc(a, (size_t)(args[0]->n ? args[0]->n : 1)
                                         * sizeof *items);
        for (int i = 0; i < args[0]->n; i++) {
            const Value *it = args[0]->items[i];
            /* A failure among the elements has already been reported once, and
             * once is the right number -- so it passes through rather than
             * becoming a second complaint about the element's kind. `join` has
             * always done this; these did not, and the difference showed as a
             * diagnostic naming a line of the *description* after a check in it
             * had correctly named a line of the user's program. */
            if (value_failed(it)) return (Value *)it;
            switch (it->kind) {
            case V_TEXT: items[i] = value_int(a, (long long)it->len); break;
            case V_LIST:
            case V_NODE: items[i] = value_int(a, it->n);              break;
            default:
                return library_fail(e, x, "'sizes' wants text, lists or nodes, "
                                    "and element %d is %s", i + 1,
                                    value_kind_name(it));
            }
        }
        return list_of(a, items, args[0]->n);
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
         * **It runs to the longer of the two.** Taking the first list's
         * length silently dropped everything the second had beyond it, which
         * is how `abs(i)` came out as `abs()`: the first list was what a call
         * puts before each argument, and a call to something the description
         * does not declare puts nothing before anything, so the first list was
         * empty and so was the answer. A list that runs out contributes
         * nothing; it does not end the walk. */
        int n = args[0]->n;
        if (two && second->n > n) n = second->n;
        Value **items = arena_alloc(a, (size_t)(n ? n : 1) * sizeof *items);

        for (int i = 0; i < n; i++) {
            char  *pieces[2] = { "", "" };
            size_t lens[2]   = { 0, 0 };

            if (i < args[0]->n && value_failed(args[0]->items[i]))
                return args[0]->items[i];
            if (two && i < second->n && value_failed(second->items[i]))
                return second->items[i];

            if (i < args[0]->n
                && !value_format(a, args[0]->items[i], &pieces[0], &lens[0]))
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
