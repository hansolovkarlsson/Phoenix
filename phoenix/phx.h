/* phx.h -- the shapes Phoenix works in.
 *
 * Stage 0 is the grammar half and nothing else: read a `.phx` file that holds
 * only EBNF, scan a target file into tokens with it, match those tokens
 * against it, and print the tree that came out. No actions, no passes, no
 * code generation -- those arrive in later stages, and this file grows with
 * them rather than anticipating them.
 */
#ifndef PHX_H
#define PHX_H

#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>

/* ------------------------------------------------------------------ */
/* Arena
 *
 * Nothing is freed until the process is done with it. A compiler-compiler
 * reads a grammar, walks a file and exits; lifetimes are one run long, and an
 * allocator that says so is smaller than one that tracks them.
 */

typedef struct Arena Arena;

Arena *arena_new(void);
void   arena_free(Arena *a);
void  *arena_alloc(Arena *a, size_t n);
char  *arena_strndup(Arena *a, const char *s, size_t n);

/* ------------------------------------------------------------------ */
/* Source
 *
 * A file, held whole. Positions are byte offsets and nothing carries a line:
 * the line is wanted a few times per run, once per message, and counting
 * newlines on demand is free at that rate. Carrying one on every token and
 * every node is a field on everything.
 */

typedef struct {
    const char *path;
    char       *text;
    size_t      size;
} Source;

bool source_read(Arena *a, const char *path, Source *out);
void source_position(const Source *src, size_t off, int *line, int *col);
void source_line(const Source *src, size_t off, const char **start, size_t *len);

/* ------------------------------------------------------------------ */
/* Diagnostics
 *
 * Every message names a file, a line and a column, and prints the line with a
 * caret under it. `diag_error` records that something failed; the exit status
 * is a question to `diag_failed`.
 */

void diag_error(const Source *src, size_t off, const char *fmt, ...);
void diag_warn(const Source *src, size_t off, const char *fmt, ...);
void diag_note(const char *fmt, ...);
bool diag_failed(void);
int  diag_errors(void);

/* ------------------------------------------------------------------ */
/* The tree a grammar is
 *
 * Wirth's notation, plus the three things it needs before it can describe a
 * lexer and not one thing more: a character range, a negation, and the string
 * escapes. All three are lexical only, and using one in a syntactic rule --
 * where there are tokens and no characters to ask about -- is an error with a
 * line number.
 */

typedef enum {
    G_LIT,    /* "text"        a terminal: characters, or a token's spelling */
    G_RANGE,  /* "a" .. "z"    one character between two, inclusive          */
    G_NAME,   /* rule-name     a reference, resolved to an index             */
    G_SEQ,    /* a b c         all of them, in order                         */
    G_ALT,    /* a | b         ordered choice: b is tried only if a failed   */
    G_OPT,    /* [ a ]         a, or nothing                                 */
    G_REP,    /* { a }         a as many times as it will go, greedily       */
    G_NOT     /* ! a           one character, provided a does not match here */
} GKind;

typedef struct GNode GNode;
struct GNode {
    GKind   kind;
    char   *text;    /* LIT: the text.  RANGE: the low end.  NAME: the name  */
    char   *upto;    /* RANGE: the high end                                  */
    char   *folded;  /* LIT: text lowercased, for %ignorecase                */
    int     len;     /* LIT: its length, since a literal may hold a NUL      */
    GNode **kids;
    int     nkids;
    int     ref;     /* NAME: the rule it names, or -1 until resolved        */
    size_t  pos;
};

typedef struct {
    char   *name;
    GNode  *body;
    bool    lexical;   /* declared before %syntax                           */
    bool    fragment;  /* %fragment: a helper, never a token on its own     */
    bool    skip;      /* %skip: produced, then thrown away                 */
    bool    used;      /* referred to by some other rule                    */
    bool    nullable;  /* can match nothing -- wanted by the checks         */
    size_t  pos;
} Rule;

typedef struct {
    Arena  *arena;
    Source  src;

    Rule   *rules;
    int     nrules;
    int     caprules;

    int     start;       /* the goal rule                                   */
    bool    ignorecase;

    char  **reserved;    /* word-shaped literals from the syntactic half    */
    int     nreserved;
} Grammar;

/* Reads a `.phx` file. Answers NULL when it could not, having said why. */
Grammar *grammar_read(Arena *a, const char *path);

/* Resolves names and runs every check. Reports as it goes. */
bool grammar_check(Grammar *g);

/* Prints the grammar back in the notation it was written in. */
void grammar_dump(FILE *out, const Grammar *g);

/* Finds a rule by name, or -1. */
int grammar_find(const Grammar *g, const char *name, size_t len);

/* ------------------------------------------------------------------ */
/* Tokens
 *
 * The lexical half takes the longest match over every token rule, which is
 * what a lexer does and what makes `"<" | "<="` a question nobody has to
 * answer. Ties go to the rule declared first.
 */

typedef struct {
    int         kind;   /* the lexical rule that matched                    */
    const char *text;
    size_t      len;
    size_t      pos;
} Token;

typedef struct {
    Token *items;
    int    n;
    int    cap;
} Tokens;

bool lex_run(Arena *a, const Grammar *g, const Source *src, Tokens *out);

/* Whether the lexical half can produce this exact text as one whole token.
 * Asked of every literal in the syntactic half, so that a grammar naming a
 * `","` no token rule spells is refused when it is read rather than when a
 * file first happens to contain a comma. */
bool lex_produces(const Grammar *g, const char *text, size_t len);
void tokens_dump(FILE *out, const Grammar *g, const Source *src, const Tokens *t);

/* ------------------------------------------------------------------ */
/* The tree a file becomes
 *
 * One node per rule that matched, one leaf per token consumed. This is the
 * concrete tree -- every bracket and semicolon is in it -- because stage 0 has
 * no way to be told what to leave out. Stage 1 adds one.
 */

typedef struct PNode PNode;
struct PNode {
    const char *name;    /* the rule, or NULL for a leaf                    */
    int         rule;    /* the rule index, or -1 for a literal leaf        */
    const char *text;    /* a leaf's spelling                               */
    size_t      len;
    size_t      pos;
    PNode     **kids;
    int         nkids;
    int         capkids;
};

/* Matches the tokens against the grammar. Answers NULL on a syntax error,
 * having reported where the match got furthest and what it wanted there. */
PNode *parse_run(Arena *a, const Grammar *g, const Source *src, const Tokens *t);

void tree_dump(FILE *out, const PNode *root);

#endif /* PHX_H */
