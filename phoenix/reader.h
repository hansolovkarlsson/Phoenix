/* reader.h -- the `.phx` file's own tokens, shared between the half that
 * reads grammars and the half that reads passes.
 *
 * Internal to Phoenix: nothing outside `phoenix/` includes this.
 */
#ifndef PHX_READER_H
#define PHX_READER_H

#include "phx.h"

typedef enum {
    T_EOF,
    T_NAME,
    T_LIT,
    T_NUMBER,     /*  45     */
    T_REAL,       /*  4.5    */
    T_DEFSYM,     /*  =  :=  ::=  */
    T_DOT,
    T_DOTDOT,
    T_ATTRIBUTE,  /*  .name  -- a dot with a lower-case letter right after it */
    T_BAR,
    T_LPAREN, T_RPAREN,
    T_LBRACK, T_RBRACK,
    T_LBRACE, T_RBRACE,
    T_BANG,
    T_ARROW,      /*  ->     */
    T_FATARROW,   /*  =>     */
    T_DOLLAR,     /*  $      */
    T_COLON,      /*  :      */
    T_COMMA,      /*  ,      */
    T_ELLIPSIS,   /*  ...    */
    T_UNDER,      /*  _      */
    T_PLUS, T_MINUS, T_STAR, T_SLASH,
    T_NE, T_LT, T_GT, T_LE, T_GE,
    T_DIRECTIVE   /*  %name  */
} TKind;

typedef struct {
    TKind      kind;
    char      *text;   /* NAME, DIRECTIVE: the name. LIT: the decoded bytes */
    long long  value;  /* NUMBER: what it says                              */
    double     real;   /* REAL: what it says                                */
    size_t     len;    /* LIT may hold a NUL, so the length is carried       */
    size_t     pos;
    int        line;
} MToken;

typedef struct {
    Arena   *a;
    Grammar *g;
    Source  *src;

    MToken  *toks;
    int      n;
    int      cap;
    int      at;
} Reader;

/* scanning, in grammar.c */
bool    reader_scan(Reader *r);

/* the cursor */
MToken *reader_peek(Reader *r);
MToken *reader_peek2(Reader *r);
MToken *reader_next(Reader *r);
bool    reader_at(Reader *r, TKind kind);

/* the shared expression reader, in expr.c */
Expr   *read_expr(Reader *r);
Expr   *expr_new(Reader *r, XKind kind, size_t pos);
void    expr_add(Reader *r, Expr *parent, const char *field, Expr *kid);

/* the pass half, in pass.c */
bool    read_passes(Reader *r, MToken *directive);
bool    read_driver(Reader *r, MToken *directive);

/* reading one file into a grammar, in grammar.c -- recursive, for %import */
bool    read_description(Arena *a, Grammar *g, const char *named, const char *by,
                         const Source *blamed, size_t blame);

/* where the modules that ship with phx live, in main.c */
const char *phx_library_path(Arena *a);

#endif /* PHX_READER_H */
