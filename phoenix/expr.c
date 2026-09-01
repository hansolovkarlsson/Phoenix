/* expr.c -- the meta-language's expressions.
 *
 * One reader, used twice. A stage-1 action -- what a production builds -- is a
 * strict subset of what a stage-2 pass clause computes, so there is one
 * grammar for both and no second notation to learn:
 *
 *     expression = disjunction { "of" disjunction { "," disjunction } } .
 *     disjunction = conjunction { "or" conjunction } .
 *     conjunction = comparison { "and" comparison } .
 *     comparison = sum [ ( "=" | "<>" | "<" | ">" | "<=" | ">=" ) sum ] .
 *     sum        = product { ( "+" | "-" ) product } .
 *     product    = unary { ( "*" | "/" | "div" | "mod" ) unary } .
 *     unary      = [ "not" | "-" ] postfix .
 *     postfix    = primary { "." name } .
 *     primary    = "$" ( number | name | "$" ) | number | real | literal
 *                | "true" | "false" | "nil"
 *                | name [ "(" [ argument { "," argument } ] ")" ]
 *                | "[" [ element { "," element } ] "]"
 *                | "(" expression ")" .
 *
 * The precedence is the table in docs/semantics.md and this file is what makes
 * that table true, so the two are changed together or not at all.
 */
#include "phx.h"
#include "reader.h"

#include <string.h>

#define peek(r)    reader_peek(r)
#define peek2(r)   reader_peek2(r)
#define advance(r) reader_next(r)
#define at(r, k)   reader_at((r), (k))

Expr *expr_new(Reader *r, XKind kind, size_t pos)
{
    Expr *x = arena_alloc(r->a, sizeof *x);
    x->kind = kind;
    x->pos  = pos;
    return x;
}

void expr_add(Reader *r, Expr *parent, const char *field, Expr *kid)
{
    int    n      = parent->nkids;
    Expr **kids   = arena_alloc(r->a, (size_t)(n + 1) * sizeof *kids);
    char **fields = arena_alloc(r->a, (size_t)(n + 1) * sizeof *fields);

    memcpy(kids,   parent->kids,   (size_t)n * sizeof *kids);
    memcpy(fields, parent->fields, (size_t)n * sizeof *fields);

    kids[n]   = kid;
    fields[n] = (char *)field;

    parent->kids   = kids;
    parent->fields = fields;
    parent->nkids  = n + 1;
}

/* An operator node: the operator's spelling in `name`, operands as kids. */
static Expr *binop(Reader *r, const char *op, Expr *lhs, Expr *rhs, size_t pos)
{
    Expr *x = expr_new(r, X_BINOP, pos);
    x->name = (char *)op;
    expr_add(r, x, NULL, lhs);
    expr_add(r, x, NULL, rhs);
    return x;
}

static bool is_word(Reader *r, const char *word)
{
    return at(r, T_NAME) && strcmp(peek(r)->text, word) == 0;
}

/* ------------------------------------------------------------------ */

static Expr *read_primary(Reader *r)
{
    MToken *t = peek(r);

    switch (t->kind) {
    case T_DOLLAR: {
        advance(r);

        if (at(r, T_DOLLAR)) {                    /* $$ -- the accumulator */
            MToken *d = advance(r);
            return expr_new(r, X_ACC, d->pos);
        }
        if (at(r, T_NUMBER)) {                    /* $2 -- by position     */
            MToken *n = advance(r);
            if (n->value < 1) {
                diag_error(r->src, n->pos, "$0 -- factors are counted from one");
                return NULL;
            }
            Expr *x  = expr_new(r, X_REF, n->pos);
            x->index = (int)n->value;
            return x;
        }
        if (at(r, T_NAME)) {                      /* $e -- by name         */
            MToken *n = advance(r);
            Expr *x = expr_new(r, X_REF, n->pos);
            x->name = n->text;
            return x;
        }
        diag_error(r->src, t->pos, "'$' wants a number, a name, or another '$'");
        return NULL;
    }

    case T_NUMBER: {
        advance(r);
        Expr *x = expr_new(r, X_INT, t->pos);
        x->ival = t->value;
        return x;
    }

    case T_REAL: {
        advance(r);
        Expr *x = expr_new(r, X_FLOAT, t->pos);
        x->real = t->real;
        return x;
    }

    case T_LIT: {
        advance(r);
        Expr *x = expr_new(r, X_TEXT, t->pos);
        x->name = t->text;
        x->len  = (int)t->len;
        return x;
    }

    case T_LBRACK: {
        advance(r);
        Expr *x = expr_new(r, X_LIST, t->pos);

        while (!at(r, T_RBRACK)) {
            bool   spread = false;
            size_t pos    = peek(r)->pos;
            if (at(r, T_ELLIPSIS)) { advance(r); spread = true; }

            Expr *item = read_expr(r);
            if (!item) return NULL;

            if (spread) {
                Expr *s = expr_new(r, X_SPREAD, pos);
                expr_add(r, s, NULL, item);
                item = s;
            }
            expr_add(r, x, NULL, item);

            if (at(r, T_COMMA)) { advance(r); continue; }
            break;
        }
        if (!at(r, T_RBRACK)) {
            diag_error(r->src, peek(r)->pos, "expected ']'");
            return NULL;
        }
        advance(r);
        return x;
    }

    case T_LPAREN: {
        advance(r);
        Expr *inner = read_expr(r);
        if (!inner) return NULL;
        if (!at(r, T_RPAREN)) {
            diag_error(r->src, peek(r)->pos, "expected ')'");
            return NULL;
        }
        advance(r);
        return inner;
    }

    case T_NAME: {
        advance(r);

        if (strcmp(t->text, "true") == 0 || strcmp(t->text, "false") == 0) {
            Expr *x = expr_new(r, X_BOOL, t->pos);
            x->ival = t->text[0] == 't';
            return x;
        }
        if (strcmp(t->text, "nil") == 0) return expr_new(r, X_NIL, t->pos);

        /* A capital starts a node type and a lower-case letter starts a
         * function. That is the one convention this notation asks for, and it
         * is what lets `Empty` be a node with no fields while `empty` is a call
         * with no arguments -- neither of which can be written with a bracket
         * that says which was meant. */
        bool capitalised = t->text[0] >= 'A' && t->text[0] <= 'Z';

        if (!at(r, T_LPAREN)) {
            Expr *x = expr_new(r, capitalised ? X_NODE : X_CALL, t->pos);
            x->name = t->text;
            return x;
        }
        advance(r);

        /* `Name(field: value, ...)` builds a node; `name(a, b)` calls a
         * function. The colon after the first argument is what tells them
         * apart, and a node with no fields was handled above. */
        bool is_node = capitalised;

        Expr *x = expr_new(r, is_node ? X_NODE : X_CALL, t->pos);
        x->name = t->text;

        while (!at(r, T_RPAREN)) {
            const char *field = NULL;

            if (is_node) {
                if (!at(r, T_NAME)) {
                    diag_error(r->src, peek(r)->pos, "expected a field name");
                    return NULL;
                }
                MToken *f = advance(r);
                if (!at(r, T_COLON)) {
                    diag_error(r->src, peek(r)->pos,
                               "expected ':' after the field '%s'", f->text);
                    return NULL;
                }
                advance(r);
                field = f->text;
            }

            Expr *value = read_expr(r);
            if (!value) return NULL;
            expr_add(r, x, field, value);

            if (at(r, T_COMMA)) { advance(r); continue; }
            break;
        }
        if (!at(r, T_RPAREN)) {
            diag_error(r->src, peek(r)->pos, "expected ')'");
            return NULL;
        }
        advance(r);
        return x;
    }

    default:
        diag_error(r->src, t->pos, "expected a value");
        return NULL;
    }
}

/* `$left.val` -- an attribute of whatever precedes it.
 *
 * A `.` also ends a production and ends a pass clause, and telling the two
 * apart used to be a special case here: the reader asked whether whitespace
 * preceded the dot. It is the scanner's business now -- `.val` is one token
 * and `. ` cannot be one -- so this loop has nothing to decide.
 *
 * It also works where the old rule did not quite: `at($vars, 1).name` is an
 * attribute of a *call*, and there is no reference for a space to be adjacent
 * to. */
static Expr *read_postfix(Reader *r)
{
    Expr *x = read_primary(r);
    if (!x) return NULL;

    while (at(r, T_ATTRIBUTE)) {
        MToken *attr = advance(r);

        Expr *dotted = expr_new(r, X_DOT, attr->pos);
        dotted->name = attr->text;
        expr_add(r, dotted, NULL, x);
        x = dotted;
    }
    return x;
}

static Expr *read_unary(Reader *r)
{
    if (is_word(r, "not")) {
        MToken *t = advance(r);
        Expr *inner = read_unary(r);
        if (!inner) return NULL;
        Expr *x = expr_new(r, X_UNOP, t->pos);
        x->name = "not";
        expr_add(r, x, NULL, inner);
        return x;
    }
    if (at(r, T_MINUS)) {
        MToken *t = advance(r);
        Expr *inner = read_unary(r);
        if (!inner) return NULL;
        Expr *x = expr_new(r, X_UNOP, t->pos);
        x->name = "-";
        expr_add(r, x, NULL, inner);
        return x;
    }
    return read_postfix(r);
}

static Expr *read_product(Reader *r)
{
    Expr *x = read_unary(r);
    if (!x) return NULL;

    for (;;) {
        const char *op = NULL;
        if      (at(r, T_STAR))       op = "*";
        else if (at(r, T_SLASH))      op = "/";
        else if (is_word(r, "div"))   op = "div";
        else if (is_word(r, "mod"))   op = "mod";
        else break;

        MToken *t = advance(r);
        Expr *rhs = read_unary(r);
        if (!rhs) return NULL;
        x = binop(r, op, x, rhs, t->pos);
    }
    return x;
}

static Expr *read_sum(Reader *r)
{
    Expr *x = read_product(r);
    if (!x) return NULL;

    for (;;) {
        const char *op = at(r, T_PLUS) ? "+" : at(r, T_MINUS) ? "-" : NULL;
        if (!op) break;

        MToken *t = advance(r);
        Expr *rhs = read_product(r);
        if (!rhs) return NULL;
        x = binop(r, op, x, rhs, t->pos);
    }
    return x;
}

/* Comparison does not chain: `a < b < c` is refused rather than read as
 * something nobody meant. */
static Expr *read_comparison(Reader *r)
{
    Expr *x = read_sum(r);
    if (!x) return NULL;

    const char *op = NULL;
    switch (peek(r)->kind) {
    case T_DEFSYM: op = "=";  break;
    case T_NE:     op = "<>"; break;
    case T_LT:     op = "<";  break;
    case T_GT:     op = ">";  break;
    case T_LE:     op = "<="; break;
    case T_GE:     op = ">="; break;
    default: return x;
    }

    MToken *t = advance(r);
    Expr *rhs = read_sum(r);
    if (!rhs) return NULL;

    Expr *cmp = binop(r, op, x, rhs, t->pos);

    switch (peek(r)->kind) {
    case T_DEFSYM: case T_NE: case T_LT: case T_GT: case T_LE: case T_GE:
        diag_error(r->src, peek(r)->pos,
                   "comparisons do not chain -- write 'a < b and b < c'");
        return NULL;
    default:
        return cmp;
    }
}

static Expr *read_conjunction(Reader *r)
{
    Expr *x = read_comparison(r);
    if (!x) return NULL;

    while (is_word(r, "and")) {
        MToken *t = advance(r);
        Expr *rhs = read_comparison(r);
        if (!rhs) return NULL;
        x = binop(r, "and", x, rhs, t->pos);
    }
    return x;
}

static Expr *read_disjunction(Reader *r)
{
    Expr *x = read_conjunction(r);
    if (!x) return NULL;

    while (is_word(r, "or")) {
        MToken *t = advance(r);
        Expr *rhs = read_conjunction(r);
        if (!rhs) return NULL;
        x = binop(r, "or", x, rhs, t->pos);
    }
    return x;
}

Expr *read_expr(Reader *r)
{
    Expr *x = read_disjunction(r);
    if (!x) return NULL;

    /* `"text {} {}" of a, b` -- the loosest thing there is, so that a template
     * never needs parentheses around what fills it. */
    if (!is_word(r, "of")) return x;

    MToken *t = advance(r);
    Expr *fmt = expr_new(r, X_FORMAT, t->pos);
    expr_add(r, fmt, NULL, x);

    for (;;) {
        Expr *arg = read_disjunction(r);
        if (!arg) return NULL;
        expr_add(r, fmt, NULL, arg);
        if (!at(r, T_COMMA)) break;
        advance(r);
    }
    return fmt;
}
