/* grammar.c -- read a `.phx` file into a grammar.
 *
 * The notation is Wirth's, from *What can we do about the unnecessary
 * diversity of notation for syntactic definitions* (1977) and the Pascal
 * report, which is the one nearly every published grammar is written in:
 *
 *     production = identifier "=" expression "." .
 *     expression = term { "|" term } .
 *     term       = factor { factor } .
 *     factor     = identifier | literal | "(" expression ")"
 *                | "[" expression "]" | "{" expression "}" .
 *
 * That grammar is written above in its own notation, which is the property
 * worth having: it describes itself, so there is nothing to learn twice.
 *
 * The older shape is read by the same reader, because "a file in BNF" means
 * that one at least as often:
 *
 *     <expression> ::= <term> | <term> "+" <expression>
 *
 * So `<name>` is a name, `=` and `:=` and `::=` are all the definition symbol,
 * and the `.` ending a production is optional -- a production ends when the
 * next two tokens are a name and a definition symbol, which is what "one per
 * line" means once you stop assuming lines matter.
 *
 * Three additions, and no more. Wirth's notation cannot describe a lexer: it
 * has no range, no way to say "any character but this", and no way to write a
 * tab. Each of those is needed before one file can be read.
 *
 *     "a" .. "z"   a range of one character
 *     ! factor     one character, provided this does not match here
 *     "\n" "\t"    the escapes, inside a literal
 *
 * All three are lexical only. Using one in a syntactic rule asks a question
 * about characters where there are only tokens, and is refused with a line
 * number rather than failing quietly.
 */
#include "phx.h"

#include <stdlib.h>
#include <string.h>

/* ------------------------------------------------------------------ */
/* The grammar file's own tokens */

typedef enum {
    T_EOF,
    T_NAME,
    T_LIT,
    T_DEFSYM,     /*  =  :=  ::=  */
    T_DOT,
    T_DOTDOT,
    T_BAR,
    T_LPAREN, T_RPAREN,
    T_LBRACK, T_RBRACK,
    T_LBRACE, T_RBRACE,
    T_BANG,
    T_DIRECTIVE   /*  %name  */
} TKind;

typedef struct {
    TKind   kind;
    char   *text;   /* NAME, DIRECTIVE: the name. LIT: the decoded bytes.   */
    size_t  len;    /* LIT may hold a NUL, so the length is carried         */
    size_t  pos;
    int     line;
} MToken;

typedef struct {
    Arena   *a;
    Grammar *g;
    Source  *src;

    MToken  *toks;
    int      n;
    int      cap;
    int      at;      /* the cursor, while parsing */
} Reader;

/* ------------------------------------------------------------------ */
/* Characters. ASCII, deliberately: a grammar that wants a byte outside it
 * writes the byte, and what a letter is belongs to the grammar being read
 * rather than to this program. The one place Phoenix decides is rule names. */

static bool is_digit(int c)  { return c >= '0' && c <= '9'; }
static bool is_alpha(int c)  { return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'); }
static bool is_start(int c)  { return is_alpha(c) || c == '_'; }
static bool is_body(int c)   { return is_start(c) || is_digit(c) || c == '-'; }
static bool is_space(int c)  { return c == ' ' || c == '\t' || c == '\r' || c == '\n'; }

static int hex_value(int c)
{
    if (is_digit(c))              return c - '0';
    if (c >= 'a' && c <= 'f')     return c - 'a' + 10;
    if (c >= 'A' && c <= 'F')     return c - 'A' + 10;
    return -1;
}

/* ------------------------------------------------------------------ */
/* Scanning the grammar file */

static void push(Reader *r, MToken t)
{
    if (r->n == r->cap) {
        int    cap  = r->cap ? r->cap * 2 : 256;
        MToken *big = arena_alloc(r->a, (size_t)cap * sizeof *big);
        memcpy(big, r->toks, (size_t)r->n * sizeof *big);
        r->toks = big;
        r->cap  = cap;
    }
    r->toks[r->n++] = t;
}

/* A literal, `"..."` or `'...'`, with the escapes decoded. */
static bool scan_literal(Reader *r, size_t *ip, int line)
{
    const char *s     = r->src->text;
    size_t      size  = r->src->size;
    size_t      i     = *ip;
    size_t      start = i;
    char        quote = s[i++];

    char  *buf = arena_alloc(r->a, size - i + 1);
    size_t len = 0;

    while (i < size && s[i] != quote) {
        if (s[i] == '\n') break;                      /* unterminated */

        if (s[i] == '\\' && i + 1 < size) {
            i++;
            switch (s[i]) {
            case 'n':  buf[len++] = '\n'; i++; break;
            case 't':  buf[len++] = '\t'; i++; break;
            case 'r':  buf[len++] = '\r'; i++; break;
            case '0':  buf[len++] = '\0'; i++; break;
            case '\\': buf[len++] = '\\'; i++; break;
            case '"':  buf[len++] = '"';  i++; break;
            case '\'': buf[len++] = '\''; i++; break;
            case 'x': {
                int hi, lo;
                if (i + 2 < size && (hi = hex_value(s[i + 1])) >= 0
                                 && (lo = hex_value(s[i + 2])) >= 0) {
                    buf[len++] = (char)(hi * 16 + lo);
                    i += 3;
                } else {
                    diag_error(r->src, i, "\\x wants two hexadecimal digits");
                    return false;
                }
                break;
            }
            default:
                diag_error(r->src, i, "unknown escape \\%c", s[i]);
                return false;
            }
            continue;
        }
        buf[len++] = s[i++];
    }

    if (i >= size || s[i] != quote) {
        diag_error(r->src, start, "unterminated literal");
        return false;
    }
    i++;                                              /* the closing quote */

    buf[len] = '\0';
    push(r, (MToken){ .kind = T_LIT, .text = buf, .len = len,
                      .pos = start, .line = line });
    *ip = i;
    return true;
}

static bool scan(Reader *r)
{
    const char *s    = r->src->text;
    size_t      size = r->src->size;
    size_t      i    = 0;
    int         line = 1;

    while (i < size) {
        char c = s[i];

        if (c == '\n') { line++; i++; continue; }
        if (is_space(c))         { i++; continue; }

        /* `(* a comment *)`. It does not nest, which is Wirth's rule and
         * Pascal's. `(*` has to be tried before `(`. */
        if (c == '(' && i + 1 < size && s[i + 1] == '*') {
            size_t start = i;
            i += 2;
            while (i + 1 < size && !(s[i] == '*' && s[i + 1] == ')')) {
                if (s[i] == '\n') line++;
                i++;
            }
            if (i + 1 >= size) {
                diag_error(r->src, start, "unterminated comment");
                return false;
            }
            i += 2;
            continue;
        }

        /* `; to end of line` -- Solveig's comment, so that a `.phx` and a
         * `.sol` can be annotated the same way. */
        if (c == ';') {
            while (i < size && s[i] != '\n') i++;
            continue;
        }

        size_t start = i;

        if (c == '"' || c == '\'') {
            if (!scan_literal(r, &i, line)) return false;
            continue;
        }

        /* `<name>` -- the older notation's way of writing a name. */
        if (c == '<' && i + 1 < size && is_start(s[i + 1])) {
            size_t j = i + 1;
            while (j < size && is_body(s[j])) j++;
            if (j < size && s[j] == '>') {
                push(r, (MToken){ .kind = T_NAME,
                                  .text = arena_strndup(r->a, s + i + 1, j - i - 1),
                                  .len  = j - i - 1, .pos = start, .line = line });
                i = j + 1;
                continue;
            }
        }

        if (is_start(c)) {
            size_t j = i;
            while (j < size && is_body(s[j])) j++;
            push(r, (MToken){ .kind = T_NAME,
                              .text = arena_strndup(r->a, s + i, j - i),
                              .len  = j - i, .pos = start, .line = line });
            i = j;
            continue;
        }

        if (c == '%' && i + 1 < size && is_start(s[i + 1])) {
            size_t j = i + 1;
            while (j < size && is_body(s[j])) j++;
            push(r, (MToken){ .kind = T_DIRECTIVE,
                              .text = arena_strndup(r->a, s + i + 1, j - i - 1),
                              .len  = j - i - 1, .pos = start, .line = line });
            i = j;
            continue;
        }

        /* Two characters before one, every time. `.` before `..` would mean
         * the reader never saw a range. */
        if (c == ':' && i + 2 < size && s[i + 1] == ':' && s[i + 2] == '=') {
            push(r, (MToken){ .kind = T_DEFSYM, .pos = start, .line = line });
            i += 3; continue;
        }
        if (c == ':' && i + 1 < size && s[i + 1] == '=') {
            push(r, (MToken){ .kind = T_DEFSYM, .pos = start, .line = line });
            i += 2; continue;
        }
        if (c == '.' && i + 1 < size && s[i + 1] == '.') {
            push(r, (MToken){ .kind = T_DOTDOT, .pos = start, .line = line });
            i += 2; continue;
        }

        TKind kind;
        switch (c) {
        case '=': kind = T_DEFSYM; break;
        case '.': kind = T_DOT;    break;
        case '|': kind = T_BAR;    break;
        case '(': kind = T_LPAREN; break;
        case ')': kind = T_RPAREN; break;
        case '[': kind = T_LBRACK; break;
        case ']': kind = T_RBRACK; break;
        case '{': kind = T_LBRACE; break;
        case '}': kind = T_RBRACE; break;
        case '!': kind = T_BANG;   break;
        default:
            diag_error(r->src, i, "stray '%c' in the grammar", c);
            return false;
        }
        push(r, (MToken){ .kind = kind, .pos = start, .line = line });
        i++;
    }

    push(r, (MToken){ .kind = T_EOF, .pos = size, .line = line });
    return true;
}

/* ------------------------------------------------------------------ */
/* Reading the notation */

static MToken *peek(Reader *r)       { return &r->toks[r->at]; }
static MToken *peek2(Reader *r)      { return &r->toks[r->at + (r->toks[r->at].kind == T_EOF ? 0 : 1)]; }
static MToken *advance(Reader *r)    { return &r->toks[r->at++]; }
static bool    at(Reader *r, TKind k){ return r->toks[r->at].kind == k; }

static GNode *node(Reader *r, GKind kind, size_t pos)
{
    GNode *n = arena_alloc(r->a, sizeof *n);
    n->kind = kind;
    n->ref  = -1;
    n->pos  = pos;
    return n;
}

static void add_kid(Reader *r, GNode *parent, GNode *kid)
{
    GNode **kids = arena_alloc(r->a, (size_t)(parent->nkids + 1) * sizeof *kids);
    memcpy(kids, parent->kids, (size_t)parent->nkids * sizeof *kids);
    kids[parent->nkids] = kid;
    parent->kids = kids;
    parent->nkids++;
}

static char *fold(Arena *a, const char *s, size_t len)
{
    char *p = arena_strndup(a, s, len);
    for (size_t i = 0; i < len; i++)
        if (p[i] >= 'A' && p[i] <= 'Z') p[i] = (char)(p[i] - 'A' + 'a');
    return p;
}

static GNode *read_expression(Reader *r);

/* Whether the cursor is at something a factor can begin with -- and, for a
 * name, whether that name is the start of the *next* production rather than
 * part of this one. That test is what makes the trailing `.` optional. */
static bool starts_factor(Reader *r)
{
    switch (peek(r)->kind) {
    case T_NAME:
        return peek2(r)->kind != T_DEFSYM;
    case T_LIT: case T_LPAREN: case T_LBRACK: case T_LBRACE: case T_BANG:
        return true;
    default:
        return false;
    }
}

static GNode *read_factor(Reader *r)
{
    MToken *t = peek(r);

    switch (t->kind) {
    case T_NAME: {
        advance(r);
        GNode *n = node(r, G_NAME, t->pos);
        n->text  = t->text;
        return n;
    }

    case T_LIT: {
        advance(r);
        if (at(r, T_DOTDOT)) {
            advance(r);
            if (!at(r, T_LIT)) {
                diag_error(r->src, peek(r)->pos, "a range wants a literal after '..'");
                return NULL;
            }
            MToken *hi = advance(r);
            if (t->len != 1 || hi->len != 1) {
                diag_error(r->src, t->pos,
                           "a range runs between two single characters");
                return NULL;
            }
            GNode *n = node(r, G_RANGE, t->pos);
            n->text  = t->text;
            n->upto  = hi->text;
            return n;
        }
        GNode *n  = node(r, G_LIT, t->pos);
        n->text   = t->text;
        n->len    = (int)t->len;
        n->folded = fold(r->a, t->text, t->len);
        return n;
    }

    case T_LPAREN: case T_LBRACK: case T_LBRACE: {
        advance(r);
        TKind close = t->kind == T_LPAREN ? T_RPAREN
                    : t->kind == T_LBRACK ? T_RBRACK : T_RBRACE;
        const char *shut = t->kind == T_LPAREN ? ")"
                         : t->kind == T_LBRACK ? "]" : "}";

        GNode *inner = read_expression(r);
        if (!inner) return NULL;
        if (!at(r, close)) {
            diag_error(r->src, peek(r)->pos, "expected '%s'", shut);
            return NULL;
        }
        advance(r);

        if (t->kind == T_LPAREN) return inner;

        GNode *n = node(r, t->kind == T_LBRACK ? G_OPT : G_REP, t->pos);
        add_kid(r, n, inner);
        return n;
    }

    case T_BANG: {
        advance(r);
        GNode *inner = read_factor(r);
        if (!inner) return NULL;
        GNode *n = node(r, G_NOT, t->pos);
        add_kid(r, n, inner);
        return n;
    }

    default:
        diag_error(r->src, t->pos, "expected a name, a literal or a bracket");
        return NULL;
    }
}

static GNode *read_term(Reader *r)
{
    GNode *seq = node(r, G_SEQ, peek(r)->pos);

    while (starts_factor(r)) {
        GNode *f = read_factor(r);
        if (!f) return NULL;
        add_kid(r, seq, f);
    }

    /* One factor needs no sequence around it. Zero is `empty = .`, which is
     * a real production and matches nothing. */
    return seq->nkids == 1 ? seq->kids[0] : seq;
}

static GNode *read_expression(Reader *r)
{
    GNode *first = read_term(r);
    if (!first) return NULL;
    if (!at(r, T_BAR)) return first;

    GNode *alt = node(r, G_ALT, first->pos);
    add_kid(r, alt, first);

    while (at(r, T_BAR)) {
        advance(r);
        GNode *next = read_term(r);
        if (!next) return NULL;
        add_kid(r, alt, next);
    }
    return alt;
}

/* ------------------------------------------------------------------ */
/* Rules and directives */

int grammar_find(const Grammar *g, const char *name, size_t len)
{
    for (int i = 0; i < g->nrules; i++)
        if (strlen(g->rules[i].name) == len && memcmp(g->rules[i].name, name, len) == 0)
            return i;
    return -1;
}

static Rule *add_rule(Reader *r, const char *name, size_t pos, bool lexical)
{
    Grammar *g = r->g;
    if (g->nrules == g->caprules) {
        int   cap = g->caprules ? g->caprules * 2 : 64;
        Rule *big = arena_alloc(r->a, (size_t)cap * sizeof *big);
        memcpy(big, g->rules, (size_t)g->nrules * sizeof *big);
        g->rules    = big;
        g->caprules = cap;
    }
    Rule *rule = &g->rules[g->nrules++];
    memset(rule, 0, sizeof *rule);
    rule->name    = (char *)name;
    rule->pos     = pos;
    rule->lexical = lexical;
    return rule;
}

/* A directive's arguments are the names that follow it on the same line. */
static void mark_named(Reader *r, int line, void (*mark)(Reader *, MToken *))
{
    while (at(r, T_NAME) && peek(r)->line == line)
        mark(r, advance(r));
}

static void mark_fragment(Reader *r, MToken *t)
{
    int i = grammar_find(r->g, t->text, t->len);
    if (i < 0) { add_rule(r, t->text, t->pos, true)->fragment = true; return; }
    r->g->rules[i].fragment = true;
}

static void mark_skip(Reader *r, MToken *t)
{
    int i = grammar_find(r->g, t->text, t->len);
    if (i < 0) { add_rule(r, t->text, t->pos, true)->skip = true; return; }
    r->g->rules[i].skip = true;
}

/* `%fragment` and `%skip` may name a rule before it is written, so the name is
 * booked with an empty body and filled in when the production arrives. This
 * finds that booking rather than declaring the rule twice. */
static Rule *rule_for(Reader *r, MToken *name, bool lexical)
{
    int i = grammar_find(r->g, name->text, name->len);
    if (i >= 0) {
        Rule *rule = &r->g->rules[i];
        if (rule->body) {
            diag_error(r->src, name->pos, "'%s' is defined twice", rule->name);
            diag_note("the first was on line %d", 0);
            return NULL;
        }
        rule->lexical = lexical;
        rule->pos     = name->pos;
        return rule;
    }
    return add_rule(r, name->text, name->pos, lexical);
}

static bool read_file(Reader *r)
{
    Grammar *g       = r->g;
    bool     lexical = true;       /* %tokens is the default, so it is silent */
    char    *want_start = NULL;

    while (!at(r, T_EOF)) {
        if (at(r, T_DIRECTIVE)) {
            MToken *d = advance(r);

            if      (strcmp(d->text, "tokens")     == 0) lexical = true;
            else if (strcmp(d->text, "syntax")     == 0) lexical = false;
            else if (strcmp(d->text, "ignorecase") == 0) g->ignorecase = true;
            else if (strcmp(d->text, "fragment")   == 0) mark_named(r, d->line, mark_fragment);
            else if (strcmp(d->text, "skip")       == 0) mark_named(r, d->line, mark_skip);
            else if (strcmp(d->text, "start")      == 0) {
                if (!at(r, T_NAME)) {
                    diag_error(r->src, d->pos, "%%start wants the name of a rule");
                    return false;
                }
                want_start = advance(r)->text;
            } else {
                diag_error(r->src, d->pos, "unknown directive %%%s", d->text);
                diag_note("the directives are %%tokens %%syntax %%fragment "
                          "%%skip %%start %%ignorecase");
                return false;
            }
            continue;
        }

        if (!at(r, T_NAME)) {
            diag_error(r->src, peek(r)->pos, "expected a rule name");
            return false;
        }
        MToken *name = advance(r);

        if (!at(r, T_DEFSYM)) {
            diag_error(r->src, peek(r)->pos, "expected '=' after '%s'", name->text);
            return false;
        }
        advance(r);

        Rule *rule = rule_for(r, name, lexical);
        if (!rule) return false;

        rule->body = read_expression(r);
        if (!rule->body) return false;

        if (at(r, T_DOT)) advance(r);      /* optional, as the header says */
    }

    if (want_start) {
        int i = grammar_find(g, want_start, strlen(want_start));
        if (i < 0) {
            diag_error(&g->src, 0, "%%start names '%s', which is not a rule", want_start);
            return false;
        }
        g->start = i;
    } else {
        g->start = -1;
        for (int i = 0; i < g->nrules; i++)
            if (!g->rules[i].lexical) { g->start = i; break; }
    }
    return true;
}

/* ------------------------------------------------------------------ */

Grammar *grammar_read(Arena *a, const char *path)
{
    Grammar *g = arena_alloc(a, sizeof *g);
    g->arena   = a;

    if (!source_read(a, path, &g->src)) return NULL;

    Reader r = { .a = a, .g = g, .src = &g->src };
    if (!scan(&r))      return NULL;
    if (!read_file(&r)) return NULL;
    if (!grammar_check(g)) return NULL;

    return g;
}

/* ------------------------------------------------------------------ */
/* Printing a grammar back out */

static void dump_node(FILE *out, const Grammar *g, const GNode *n, GKind outer);

static void dump_literal(FILE *out, const char *s, int len)
{
    fputc('"', out);
    for (int i = 0; i < len; i++) {
        switch (s[i]) {
        case '\n': fputs("\\n", out);  break;
        case '\t': fputs("\\t", out);  break;
        case '\r': fputs("\\r", out);  break;
        case '"':  fputs("\\\"", out); break;
        case '\\': fputs("\\\\", out); break;
        default:   fputc(s[i], out);   break;
        }
    }
    fputc('"', out);
}

static void dump_kids(FILE *out, const Grammar *g, const GNode *n,
                      const char *between, GKind outer)
{
    for (int i = 0; i < n->nkids; i++) {
        if (i) fputs(between, out);
        dump_node(out, g, n->kids[i], outer);
    }
}

static void dump_node(FILE *out, const Grammar *g, const GNode *n, GKind outer)
{
    switch (n->kind) {
    case G_LIT:   dump_literal(out, n->text, n->len); break;
    case G_RANGE: dump_literal(out, n->text, 1);
                  fputs(" .. ", out);
                  dump_literal(out, n->upto, 1); break;
    case G_NAME:  fputs(n->text, out); break;
    case G_SEQ:
        if (n->nkids == 0) break;                     /* the empty production */
        dump_kids(out, g, n, " ", G_SEQ);
        break;
    case G_ALT:
        if (outer == G_SEQ) fputs("( ", out);
        dump_kids(out, g, n, " | ", G_ALT);
        if (outer == G_SEQ) fputs(" )", out);
        break;
    case G_OPT:   fputs("[ ", out); dump_node(out, g, n->kids[0], G_ALT); fputs(" ]", out); break;
    case G_REP:   fputs("{ ", out); dump_node(out, g, n->kids[0], G_ALT); fputs(" }", out); break;
    case G_NOT:   fputs("! ", out); dump_node(out, g, n->kids[0], G_SEQ); break;
    }
}

void grammar_dump(FILE *out, const Grammar *g)
{
    bool lexical = true;

    for (int i = 0; i < g->nrules; i++) {
        const Rule *rule = &g->rules[i];

        if (lexical && !rule->lexical) {
            fputs("\n%syntax\n", out);
            if (g->ignorecase) fputs("%ignorecase\n", out);
            if (g->start >= 0) fprintf(out, "%%start %s\n", g->rules[g->start].name);
            fputc('\n', out);
            lexical = false;
        }

        fprintf(out, "%-22s = ", rule->name);
        if (rule->body) dump_node(out, g, rule->body, G_ALT);
        fputs(" .", out);

        if (rule->fragment) fputs("      (* fragment *)", out);
        if (rule->skip)     fputs("      (* skipped *)", out);
        fputc('\n', out);
    }
}
