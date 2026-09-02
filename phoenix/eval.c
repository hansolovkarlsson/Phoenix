/* eval.c -- what an expression in the meta-language answers.
 *
 * docs/semantics.md is the specification and this file is what makes it true;
 * the two are changed together or not at all. Every rule that page states --
 * checked integers, floored division, no implicit conversion, structural
 * equality, left-to-right order -- is enforced here rather than borrowed from
 * C, so that a second backend has something exact to agree with.
 */
#include "phx.h"

#include <limits.h>
#include <math.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ------------------------------------------------------------------ */
/* Making values */

static Value *fresh(Arena *a, VKind kind)
{
    Value *v = arena_alloc(a, sizeof *v);
    v->kind  = kind;
    return v;
}

Value *value_int(Arena *a, long long n)   { Value *v = fresh(a, V_INT);   v->ival = n; return v; }
Value *value_float(Arena *a, double d)    { Value *v = fresh(a, V_FLOAT); v->real = d; return v; }
Value *value_bool(Arena *a, bool b)       { Value *v = fresh(a, V_BOOL);  v->ival = b; return v; }
Value *value_nil(Arena *a)                { return fresh(a, V_NIL); }
Value *value_error(Arena *a)              { return fresh(a, V_ERROR); }
bool   value_failed(const Value *v)       { return v && v->kind == V_ERROR; }

Value *value_text(Arena *a, const char *text, size_t len)
{
    Value *v = fresh(a, V_TEXT);
    v->text  = text;
    v->len   = len;
    return v;
}

const char *value_kind_name(const Value *v)
{
    switch (v->kind) {
    case V_NODE:  return v->type ? v->type : "node";
    case V_TEXT:  return "text";
    case V_LIST:  return "list";
    case V_INT:   return "integer";
    case V_FLOAT: return "float";
    case V_BOOL:  return "boolean";
    case V_NIL:   return "nil";
    case V_ERROR: return "a failure";
    }
    return "value";
}

/* ------------------------------------------------------------------ */
/* Writing a value, the way `of` writes it */

/* The shortest decimal that reads back as the same double. Trying each
 * precision in turn is not clever, and it is exact and identical everywhere,
 * which is what the conformance rule needs. */
static int format_float(double d, char *buf, size_t size)
{
    if (isnan(d))      return snprintf(buf, size, "nan");
    if (isinf(d))      return snprintf(buf, size, d < 0 ? "-infinity" : "infinity");

    for (int digits = 1; digits <= 17; digits++) {
        int wrote = snprintf(buf, size, "%.*g", digits, d);
        if (wrote > 0 && (size_t)wrote < size && strtod(buf, NULL) == d) return wrote;
    }
    return snprintf(buf, size, "%.17g", d);
}

bool value_format(Arena *a, const Value *v, char **out, size_t *len)
{
    char buf[64];
    int  wrote;

    switch (v->kind) {
    case V_TEXT:
        *out = (char *)v->text;
        *len = v->len;
        return true;

    case V_INT:   wrote = snprintf(buf, sizeof buf, "%lld", v->ival);   break;
    case V_BOOL:  wrote = snprintf(buf, sizeof buf, "%s", v->ival ? "true" : "false"); break;
    case V_FLOAT: wrote = format_float(v->real, buf, sizeof buf);       break;

    case V_ERROR:
        return false;
    case V_NIL:
        diag_note("nil has no written form -- a pass that wants one says what it is");
        return false;
    case V_NODE:
    case V_LIST:
        diag_note("a %s has no written form -- a pass that wants one says what it is",
                  value_kind_name(v));
        return false;
    }

    *out = arena_strndup(a, buf, (size_t)wrote);
    *len = (size_t)wrote;
    return true;
}

/* ------------------------------------------------------------------ */
/* Structural equality
 *
 * Two values are equal when they are indistinguishable, all the way down.
 * Different kinds are unequal rather than an error, so that a guard may ask
 * `$x = nil` without knowing what `$x` is.
 */

bool value_equal(const Value *a, const Value *b)
{
    if (a->kind != b->kind) return false;

    switch (a->kind) {
    case V_ERROR:
    case V_NIL:   return true;
    case V_BOOL:
    case V_INT:   return a->ival == b->ival;
    case V_FLOAT: return a->real == b->real;   /* nan is unequal to itself */
    case V_TEXT:  return a->len == b->len && memcmp(a->text, b->text, a->len) == 0;

    case V_LIST:
        if (a->n != b->n) return false;
        for (int i = 0; i < a->n; i++)
            if (!value_equal(a->items[i], b->items[i])) return false;
        return true;

    case V_NODE:
        if (a->n != b->n) return false;
        if (!a->type || !b->type || strcmp(a->type, b->type) != 0) return false;
        for (int i = 0; i < a->n; i++) {
            const char *fa = a->fields ? a->fields[i] : NULL;
            const char *fb = b->fields ? b->fields[i] : NULL;
            if ((fa == NULL) != (fb == NULL)) return false;
            if (fa && strcmp(fa, fb) != 0) return false;
            if (!value_equal(a->items[i], b->items[i])) return false;
        }
        return true;
    }
    return false;
}

/* ------------------------------------------------------------------ */
/* Arithmetic
 *
 * Integers are checked, and floored where the spec says floored. Every one of
 * these could have been one C operator; none of them is, because C's answers
 * are not the ones docs/semantics.md promises.
 */

static bool add_checked(long long a, long long b, long long *out)
{
    return !__builtin_add_overflow(a, b, out);
}
static bool sub_checked(long long a, long long b, long long *out)
{
    return !__builtin_sub_overflow(a, b, out);
}
static bool mul_checked(long long a, long long b, long long *out)
{
    return !__builtin_mul_overflow(a, b, out);
}

/* Floored, so that `a mod b` carries the sign of `b`. C truncates, so the
 * quotient is corrected when the signs differ and the division was not exact. */
static bool div_floored(long long a, long long b, long long *out)
{
    if (b == 0) return false;
    if (a == LLONG_MIN && b == -1) return false;      /* the one that traps */

    long long q = a / b, r = a % b;
    if (r != 0 && ((r < 0) != (b < 0))) q--;
    *out = q;
    return true;
}

static bool mod_floored(long long a, long long b, long long *out)
{
    if (b == 0) return false;
    if (a == LLONG_MIN && b == -1) { *out = 0; return true; }

    long long r = a % b;
    if (r != 0 && ((r < 0) != (b < 0))) r += b;
    *out = r;
    return true;
}

/* ------------------------------------------------------------------ */

static Value *eval_fail(Eval *e, const Expr *x, const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);

    char message[512];
    vsnprintf(message, sizeof message, fmt, ap);
    va_end(ap);

    diag_error(&e->g->src, x->pos, "%s", message);
    return NULL;
}

static Value *arith(Eval *e, const Expr *x, Value *l, Value *r)
{
    const char *op = x->name;

    if (value_failed(l)) return l;
    if (value_failed(r)) return r;

    /* No implicit conversion, anywhere. This is the rule that most protects
     * two backends from disagreeing, so it is checked before anything else. */
    if (l->kind != r->kind)
        return eval_fail(e, x, "'%s' between %s and %s -- there is no conversion, "
                          "so write int() or float()",
                    op, value_kind_name(l), value_kind_name(r));

    if (l->kind == V_TEXT && strcmp(op, "+") == 0)
        return eval_fail(e, x, "'+' does not join text -- write \"{}{}\" of a, b");

    if (l->kind == V_INT) {
        long long out;
        bool ok;

        if      (strcmp(op, "+")   == 0) ok = add_checked(l->ival, r->ival, &out);
        else if (strcmp(op, "-")   == 0) ok = sub_checked(l->ival, r->ival, &out);
        else if (strcmp(op, "*")   == 0) ok = mul_checked(l->ival, r->ival, &out);
        else if (strcmp(op, "div") == 0
              || strcmp(op, "/")   == 0) ok = div_floored(l->ival, r->ival, &out);
        else if (strcmp(op, "mod") == 0) ok = mod_floored(l->ival, r->ival, &out);
        else return eval_fail(e, x, "'%s' is not arithmetic", op);

        if (!ok) {
            if ((strcmp(op, "div") == 0 || strcmp(op, "/") == 0
                 || strcmp(op, "mod") == 0) && r->ival == 0)
                return eval_fail(e, x, "division by zero");
            return eval_fail(e, x, "this overflows a 64-bit integer");
        }
        return value_int(e->a, out);
    }

    if (l->kind == V_FLOAT) {
        double out;
        if      (strcmp(op, "+") == 0) out = l->real + r->real;
        else if (strcmp(op, "-") == 0) out = l->real - r->real;
        else if (strcmp(op, "*") == 0) out = l->real * r->real;
        else if (strcmp(op, "/") == 0) out = l->real / r->real;  /* IEEE: inf */
        else return eval_fail(e, x, "'%s' is integer arithmetic; this is a float", op);
        return value_float(e->a, out);
    }

    return eval_fail(e, x, "'%s' wants numbers, and this is %s",
                op, value_kind_name(l));
}

static Value *compare(Eval *e, const Expr *x, Value *l, Value *r)
{
    const char *op = x->name;

    if (value_failed(l)) return l;
    if (value_failed(r)) return r;

    if (strcmp(op, "=")  == 0) return value_bool(e->a,  value_equal(l, r));
    if (strcmp(op, "<>") == 0) return value_bool(e->a, !value_equal(l, r));

    /* Ordering is within a kind only: across kinds there is no order anyone
     * would agree on, and agreeing is the whole job. */
    if (l->kind != r->kind)
        return eval_fail(e, x, "'%s' between %s and %s -- there is no order across kinds",
                    op, value_kind_name(l), value_kind_name(r));

    int sign;
    switch (l->kind) {
    case V_INT:   sign = l->ival < r->ival ? -1 : l->ival > r->ival ? 1 : 0; break;
    case V_FLOAT:
        if (isnan(l->real) || isnan(r->real)) return value_bool(e->a, false);
        sign = l->real < r->real ? -1 : l->real > r->real ? 1 : 0;
        break;
    case V_TEXT: {
        size_t n = l->len < r->len ? l->len : r->len;
        int    c = memcmp(l->text, r->text, n);
        sign = c < 0 ? -1 : c > 0 ? 1 : (l->len < r->len ? -1 : l->len > r->len);
        break;
    }
    default:
        return eval_fail(e, x, "'%s' does not order a %s", op, value_kind_name(l));
    }

    if (strcmp(op, "<")  == 0) return value_bool(e->a, sign <  0);
    if (strcmp(op, ">")  == 0) return value_bool(e->a, sign >  0);
    if (strcmp(op, "<=") == 0) return value_bool(e->a, sign <= 0);
    if (strcmp(op, ">=") == 0) return value_bool(e->a, sign >= 0);

    return eval_fail(e, x, "'%s' is not a comparison", op);
}

/* ------------------------------------------------------------------ */
/* Formatting */

static Value *format(Eval *e, const Expr *x)
{
    Value *template = eval_expr(e, x->kids[0]);
    if (!template) return NULL;

    if (value_failed(template)) return template;

    if (template->kind != V_TEXT)
        return eval_fail(e, x, "'of' fills text, and this is %s",
                    value_kind_name(template));

    size_t cap  = template->len + 64;
    char  *buf  = arena_alloc(e->a, cap);
    size_t used = 0;
    int    next = 1;

    for (size_t i = 0; i < template->len; i++) {
        char c = template->text[i];

        /* `{{` and `}}` are the braces themselves. */
        if ((c == '{' || c == '}') && i + 1 < template->len
            && template->text[i + 1] == c) {
            i++;
        } else if (c == '{' && i + 1 < template->len && template->text[i + 1] == '}') {
            if (next >= x->nkids)
                return eval_fail(e, x, "this template has more {} than there are values");

            Value *arg = eval_expr(e, x->kids[next++]);
            if (!arg) return NULL;
            if (value_failed(arg)) return arg;

            char  *text;
            size_t len;
            if (!value_format(e->a, arg, &text, &len))
                return eval_fail(e, x->kids[next - 1], "a %s cannot fill a {}",
                            value_kind_name(arg));

            while (used + len + 1 > cap) {
                char *big = arena_alloc(e->a, cap * 2);
                memcpy(big, buf, used);
                buf = big;
                cap *= 2;
            }
            memcpy(buf + used, text, len);
            used += len;
            i++;
            continue;
        }

        if (used + 2 > cap) {
            char *big = arena_alloc(e->a, cap * 2);
            memcpy(big, buf, used);
            buf = big;
            cap *= 2;
        }
        buf[used++] = c;
    }

    if (next < x->nkids)
        return eval_fail(e, x, "this template has %d {} and %d value%s were given",
                    next - 1, x->nkids - 1, x->nkids == 2 ? "" : "s");

    buf[used] = '\0';
    return value_text(e->a, buf, used);
}

/* ------------------------------------------------------------------ */

Value *eval_expr(Eval *e, const Expr *x)
{
    switch (x->kind) {
    case X_INT:   return value_int(e->a, x->ival);
    case X_FLOAT: return value_float(e->a, x->real);
    case X_BOOL:  return value_bool(e->a, x->ival != 0);
    case X_NIL:   return value_nil(e->a);
    case X_TEXT:  return value_text(e->a, x->name, (size_t)x->len);

    case X_REF:
    case X_ACC:
    case X_DOT:
        return e->ref(e, x);

    case X_UNOP: {
        Value *v = eval_expr(e, x->kids[0]);
        if (!v) return NULL;

        if (value_failed(v)) return v;

        if (strcmp(x->name, "not") == 0) {
            if (v->kind != V_BOOL)
                return eval_fail(e, x, "'not' wants a boolean, and this is %s",
                            value_kind_name(v));
            return value_bool(e->a, !v->ival);
        }
        if (v->kind == V_INT) {
            long long out;
            if (!sub_checked(0, v->ival, &out))
                return eval_fail(e, x, "negating this overflows a 64-bit integer");
            return value_int(e->a, out);
        }
        if (v->kind == V_FLOAT) return value_float(e->a, -v->real);
        return eval_fail(e, x, "'-' wants a number, and this is %s", value_kind_name(v));
    }

    case X_BINOP: {
        /* `and` and `or` short-circuit, so their right side is not evaluated
         * before it is known to be needed. */
        if (strcmp(x->name, "and") == 0 || strcmp(x->name, "or") == 0) {
            Value *l = eval_expr(e, x->kids[0]);
            if (!l) return NULL;
            if (value_failed(l)) return l;
            if (l->kind != V_BOOL)
                return eval_fail(e, x, "'%s' wants booleans, and the left is %s",
                            x->name, value_kind_name(l));

            bool want = x->name[0] == 'a';
            if ((bool)l->ival != want) return l;

            Value *r = eval_expr(e, x->kids[1]);
            if (!r) return NULL;
            if (r->kind != V_BOOL)
                return eval_fail(e, x, "'%s' wants booleans, and the right is %s",
                            x->name, value_kind_name(r));
            return r;
        }

        Value *l = eval_expr(e, x->kids[0]);
        if (!l) return NULL;
        Value *r = eval_expr(e, x->kids[1]);
        if (!r) return NULL;

        switch (x->name[0]) {
        case '=': case '<': case '>':
            return compare(e, x, l, r);
        default:
            return arith(e, x, l, r);
        }
    }

    case X_FORMAT:
        return format(e, x);

    case X_LIST: {
        Value  *v     = fresh(e->a, V_LIST);
        int     cap   = x->nkids > 0 ? x->nkids : 1;
        Value **items = arena_alloc(e->a, (size_t)cap * sizeof *items);
        int     n     = 0;

        for (int i = 0; i < x->nkids; i++) {
            const Expr *item = x->kids[i];

            if (item->kind == X_SPREAD) {
                Value *inner = eval_expr(e, item->kids[0]);
                if (!inner) return NULL;

                /* `...` of something that is not a list used to spread to
                 * the thing itself, which is quiet and wrong: `[$e, ...$3]`
                 * where `$3` is an item rather than a repetition then builds
                 * a two-element list out of one expression twice, and both
                 * the tree and everything written back from it are consistent
                 * about it. A real grammar had that bug for as long as this
                 * was allowed. Miscounting an item is the likeliest way to
                 * get here, so it is refused. */
                if (inner->kind != V_LIST)
                    return eval_fail(e, item, "'...' wants a list, and this is %s",
                                     value_kind_name(inner));

                int add = inner->n;
                if (n + add > cap) {
                    cap = (n + add) * 2;
                    Value **big = arena_alloc(e->a, (size_t)cap * sizeof *big);
                    memcpy(big, items, (size_t)n * sizeof *big);
                    items = big;
                }
                for (int k = 0; k < inner->n; k++) items[n++] = inner->items[k];
                continue;
            }

            Value *got = eval_expr(e, item);
            if (!got) return NULL;

            if (n == cap) {
                cap *= 2;
                Value **big = arena_alloc(e->a, (size_t)cap * sizeof *big);
                memcpy(big, items, (size_t)n * sizeof *big);
                items = big;
            }
            items[n++] = got;
        }
        v->items = items;
        v->n     = n;
        return v;
    }

    case X_NODE: {
        Value *v = fresh(e->a, V_NODE);
        v->type  = x->name;
        /* Where in the file being compiled this belongs -- not where in the
         * .phx the action that built it sits. A diagnostic from a later pass
         * points at the user's program, which is the only place worth
         * pointing at. */
        v->pos   = e->pos;

        if (x->nkids == 0) return v;

        v->items  = arena_alloc(e->a, (size_t)x->nkids * sizeof *v->items);
        v->fields = arena_alloc(e->a, (size_t)x->nkids * sizeof *v->fields);

        for (int i = 0; i < x->nkids; i++) {
            Value *got = eval_expr(e, x->kids[i]);
            if (!got) return NULL;
            v->items[i]  = got;
            v->fields[i] = x->fields[i];
        }
        v->n = x->nkids;
        return v;
    }

    case X_CALL:
        return eval_call(e, x);

    case X_SPREAD:
        return eval_fail(e, x, "'...' belongs inside a list");
    }
    return NULL;
}
