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

/* A description may be assembled from several files, and a position has to
 * name the one it came from. The text of every file is held end to end in one
 * buffer so that an offset stays a single number, and a map says which file
 * each stretch of it came from. Everything downstream keeps working with plain
 * offsets and gets the right filename and line without knowing any of this. */

typedef struct {
    const char *path;
    size_t      start;    /* where this file begins in the joined text */
    size_t      size;
} Unit;

typedef struct {
    Unit *units;
    int   n;
    int   cap;
} SourceMap;

typedef struct {
    const char      *path;
    char            *text;
    size_t           size;
    const SourceMap *map;    /* NULL when the text is one file */
} Source;

bool source_read(Arena *a, const char *path, Source *out);

/* The same, saying nothing when the file is not there -- for looking in more
 * than one place before deciding a file is missing. */
bool source_try(Arena *a, const char *path, Source *out);
void source_position(const Source *src, size_t off, int *line, int *col);
void source_line(const Source *src, size_t off, const char **start, size_t *len);

/* Which file an offset falls in. The source's own path when there is no map. */
const char *source_path_at(const Source *src, size_t off);

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
/* What a production builds
 *
 * `-> ` after an alternative says what that alternative *means*, as opposed to
 * what it looks like. Without one, a rule answers what it matched and the tree
 * is the concrete one -- every bracket and semicolon in it. With one, the rule
 * answers the node named there.
 *
 *     statement = "print" expression ";"   -> Print(expr: $2)
 *               | "let" name ":=" expression ";" -> Let(name: $2, value: $4) .
 *
 * `$n` is the n'th factor of the sequence, counting from one and counting
 * everything -- so `$2` above is the `expression` and `$3` the `";"`. A factor
 * may be given a name instead, which survives the sequence being edited:
 *
 *     statement = "print" e:expression ";"  -> Print(expr: $e) .
 *
 * `$$` is what has been built so far, and is what makes a left fold sayable.
 * An action mentioning it *replaces* the value before it rather than following
 * it, so the flat repetition every grammar writes for a binary operator comes
 * out as the left-leaning tree it means:
 *
 *     expression = term { ( "+" | "-" ) term -> Binary(op: $1, left: $$, right: $2) } .
 */

typedef enum {
    X_NODE,    /* Type(field: value, ...), or a bare Type with no fields    */
    X_REF,     /* $2, or $name                                              */
    X_ACC,     /* $$ -- what the enclosing sequence has built so far        */
    X_TEXT,    /* "a literal"                                               */
    X_LIST,    /* [ a, b ]                                                  */
    X_SPREAD,  /* ...a  -- inside a list, opens a list out into it          */
    X_INT,     /* 45                                                        */
    X_FLOAT,   /* 4.5                                                       */
    X_BOOL,    /* true, false                                               */
    X_NIL,     /* nil                                                       */
    X_BINOP,   /* a + b   -- the spelling in `name`                         */
    X_UNOP,    /* not a, -a                                                 */
    X_CALL,    /* f(a, b)                                                   */
    X_DOT,     /* $left.val -- an attribute of another node                 */
    X_FORMAT   /* "{} {}" of a, b                                           */
} XKind;

typedef struct Expr Expr;
struct Expr {
    XKind      kind;
    char      *name;   /* X_NODE: the type. X_REF/X_DOT: the name.
                        * X_TEXT: the bytes. X_BINOP/X_UNOP/X_CALL: which    */
    int        len;    /* X_TEXT: its length                                 */
    int        index;  /* X_REF: the 1-based position, or 0 when by name     */
    long long  ival;   /* X_INT, X_BOOL                                      */
    double     real;   /* X_FLOAT                                            */
    char     **fields; /* X_NODE: one name per kid, else NULL throughout     */
    Expr     **kids;
    int        nkids;
    size_t     pos;
};

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
    char   *label;   /* the name a factor was given: `e:expression`          */
    Expr   *action;  /* SEQ: what this alternative builds, or NULL           */
    size_t  pos;
};

typedef struct {
    char   *name;
    GNode  *body;
    bool    lexical;   /* declared before %syntax                           */
    bool    fragment;  /* %fragment: a helper, never a token on its own     */
    bool    skip;      /* %skip: produced, then thrown away                 */
    bool    used;      /* referred to by some other rule                    */
    bool    required;  /* %require: a hole, filled by whoever imports this   */
    bool    nullable;  /* can match nothing -- wanted by the checks         */
    size_t  pos;
} Rule;

typedef struct Pass    Pass;   /* below -- the Grammar holds them */
typedef struct Driver  Driver;
typedef struct Rewrite Rewrite;

/* ------------------------------------------------------------------ */
/* Embedded files
 *
 *     %embed runtime "awk-runtime.c" .
 *
 * The bytes of another file, under a name a clause reads like any other value.
 *
 * **A backend that emits a language needs that language's runtime**, and a
 * description has nowhere to put one: `languages/pascal/pascal-c.phx` gets
 * away with four `#include`s because Pascal's types are C's, and
 * `languages/awk/awk-c.phx` needs seven hundred lines because awk's are not.
 * Held as literals they are unreadable and, worse, **untestable** -- the C
 * cannot be compiled or run except through a program generated from it.
 *
 * The file is read when the description is, and its bytes are frozen into
 * whatever `-o` writes, so *one file, no headers, no library* still holds. A
 * change to the embedded file is a change to the description, which is the
 * sharp edge and is the same one `%import` has.
 */
typedef struct {
    char   *name;
    char   *text;
    size_t  len;
    char   *path;   /* where it came from, for --imports */
    size_t  pos;    /* where it was named, for the checks */
} Embed;

typedef struct {
    Arena     *arena;
    Source     src;         /* every imported file, joined */
    SourceMap  map;

    char     **imported;    /* the paths already read, so none is read twice */
    int        nimported;
    int        capimported;

    Rule   *rules;
    int     nrules;
    int     caprules;

    int     start;       /* the goal rule                                   */
    bool    ignorecase;

    char  **reserved;    /* word-shaped literals from the syntactic half    */
    int     nreserved;

    Pass   *passes;
    int     npasses;
    int     cappasses;

    Driver *drivers;
    int     ndrivers;
    int     capdrivers;

    Rewrite *rewrites;
    int      nrewrites;
    int      caprewrites;

    /* `%embed runtime "awk-runtime.c"` -- a file's bytes, under a name a
     * clause can read. Frozen when the description is read, so a compiler
     * written out with `-o` still needs nothing beside it. */
    Embed   *embeds;
    int      nembeds;
    int      capembeds;

    /* `%include Include path` -- which node stands for a target file's own
     * include, and which of its fields holds the name of the file. NULL when
     * the language has no such thing, which is most of them. */
    char   *include_type;
    char   *include_field;
    size_t  include_pos;     /* where it was declared, for the checks       */

    /* A module may name rules it does not define. Reading one on its own is
     * fine; using one to parse a file is not, and this is what says so. */
    bool    incomplete;
} Grammar;

/* Reads a `.phx` file. Answers NULL when it could not, having said why. */
Grammar *grammar_read(Arena *a, const char *path);

/* Resolves names and runs every check. Reports as it goes. */
bool grammar_check(Grammar *g);

/* Prints the grammar back in the notation it was written in. */
void grammar_dump(FILE *out, const Grammar *g);

/* Prints the node types the grammar can build, and their fields -- the
 * vocabulary a pass will be written against. */
void grammar_nodes(FILE *out, const Grammar *g);

/* Finds a rule by name, or -1. */
int grammar_find(const Grammar *g, const char *name, size_t len);

/* ------------------------------------------------------------------ */
/* Passes
 *
 * A pass is clauses keyed on the vocabulary the actions build. Clauses are
 * tried **in order and the first match wins** -- the same dispatch discipline
 * as the ordered choice in the syntactic half, so the tool has one rule about
 * ordering rather than two.
 *
 *     %pass eval
 *       thread env = empty
 *
 *       Number          : val = number($text) .
 *       Binary(op: "+") : val = $left.val + $right.val .
 *       Let             : env = bind($env, $name, $value.val) .
 *       Variable        : val = lookup($env, $name) .
 *                       ! error("'{}' is not defined" of $name)
 *                           when lookup($env, $name) = nil .
 *
 * A pattern tests and binds at once: `Number(text: t)` matches a `Number` and
 * binds `t`. A field written with a value tests it; a field written with a
 * name binds it; a field left out is not looked at.
 *
 * A **list** is written `[ a, b ]` and matches a list of exactly that many,
 * each element matching. A value can be a list, so a pattern has to be able to
 * be one -- without it there is no way to ask about a field that holds several
 * things, and `Send(args: [Block(params: [])])`, which is exactly the
 * question an optimisation asks, cannot be written at all.
 */

typedef enum {
    P_TYPE,   /* Binary, or Binary(op: "+")                                 */
    P_BIND,   /* a name: matches anything and binds it                      */
    P_TEXT,   /* "literal"                                                  */
    P_INT,    /* 45                                                         */
    P_BOOL,   /* true, false                                                */
    P_NIL,    /* nil                                                        */
    P_LIST,   /* [ a, b ] -- a list of exactly that many, each matching     */
    P_ANY     /* _                                                          */
} PKind;

typedef struct Pattern Pattern;
struct Pattern {
    PKind      kind;
    char      *name;    /* P_TYPE: the type. P_BIND: the name. P_TEXT: bytes */
    int        len;
    long long  ival;
    char     **fields;  /* P_TYPE: which field each kid tests                */
    Pattern  **kids;
    int        nkids;
    size_t     pos;
};

typedef enum {
    C_SYNTH,   /* attr = expr      -- computed from this node and its kids  */
    C_DOWN,    /* down attr = expr -- handed to the children                */
    C_THREAD,  /* a threaded attribute's update, recognised by its name     */
    C_ERROR    /* ! error(...) when cond                                    */
} CKind;

typedef struct {
    CKind   kind;
    char   *attr;    /* the attribute defined, for the three that define one */
    Expr   *value;   /* the expression, or the message for C_ERROR           */
    Expr   *when;    /* C_ERROR: the condition, or NULL for always           */
    size_t  pos;
} Clause;

typedef struct {
    Pattern *pattern;
    Clause  *clauses;
    int      nclauses;
    size_t   pos;
} PassRule;

struct Pass {
    char     *name;
    char    **threads;    /* the threaded attributes, in order declared      */
    Expr    **initial;    /* what each one enters the root with              */
    int       nthreads;
    PassRule *rules;
    int       nrules;

    /* `otherwise type = "void"` -- what a node has when its own rule does not
     * work one out.
     *
     * A clause is keyed on a node type, and some attributes are answered the
     * same way by nearly every type. `languages/pascal/pascal.phx` wrote
     * `type = "void"` twenty-one times so that a node above could read a type
     * without asking which kind of statement it was; the `.sob` backend would
     * have written one line of a run table once per node type that can be a
     * statement.
     *
     * **It is still a clause about a node**, which is the whole reason this is
     * the mechanism rather than a function or a macro: the general one. It
     * runs after the node's own clauses, so it can read what they worked out,
     * and only for the attributes that rule left alone.
     */
    Clause   *defaults;
    int       ndefaults;

    size_t    pos;
};

/* ------------------------------------------------------------------ */
/* Rewrites
 *
 *     %rewrite fold bottomup
 *       Binary(op: "+", left: Number(text: a), right: Number(text: b))
 *         => Number(text: text(int(a) + int(b))) .
 *
 * A pass **decorates**: it works out attributes and leaves the tree alone. A
 * rewrite **replaces**: a node whose shape matches becomes what the `=>` says,
 * and the walk carries on. The two halves were already here -- patterns match
 * on shape and bind, and the evaluator builds nodes -- so what this adds is a
 * traversal that puts the answer back.
 *
 * It is what a pass cannot do, and the reason is the same one that made
 * `%include` a reader's job rather than a clause's: a pass answers *about* a
 * node, and some things are answered by there being a different node.
 *
 * The strategy says when a node is tried against its children:
 *
 *   bottomup   children first, then this node, once
 *   topdown    this node first, then the children of whatever it became
 *   innermost  bottom-up, and again on the result until nothing matches
 */

typedef enum {
    R_BOTTOMUP,
    R_TOPDOWN,
    R_INNERMOST
} RStrategy;

typedef struct {
    Pattern *pattern;
    Expr    *to;
    size_t   pos;
} RewriteRule;

struct Rewrite {
    char        *name;
    RStrategy    how;
    RewriteRule *rules;
    int          nrules;
    int          caprules;
    size_t       pos;
};

/* ------------------------------------------------------------------ */
/* Drivers
 *
 *     %driver c = typecheck, emit-c -> out .
 *
 * Passes in order, and which attribute of the root is the answer. A driver
 * with no `->` is a validation run: nothing is printed and the exit status is
 * the whole of what it says.
 *
 * Attributes stay on the nodes between passes, which is what makes a sequence
 * worth having -- `typecheck` leaves `type` behind and `emit-c` reads it,
 * without either knowing the other exists.
 */

struct Driver {
    char   *name;
    char  **passes;      /* by name, in the order they run */
    int     npasses;
    char   *answer;      /* the root attribute to print, or NULL */
    size_t  pos;
    size_t *pass_pos;    /* where each was named, for messages */
};

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
 * A value is one of three things, and which one a rule answers follows a
 * single rule with no exceptions: **a body that produced one value answers
 * that value; a body that produced any other number answers a node named after
 * the rule, holding them.**
 *
 * That is worth stating plainly because of what falls out of it. A chain of
 * rules that each pass one thing along -- `expression` to `term` to `factor`
 * to a number -- collapses to the number, without anybody saying so. The
 * useless interior nodes that every hand-written tree-builder exists to strip
 * are never built.
 */

typedef enum {
    V_NODE,    /* a named node with named fields                            */
    V_TEXT,    /* bytes -- what a token was spelled with, or any text       */
    V_LIST,    /* several values in order                                   */
    V_INT,     /* 64-bit signed                                             */
    V_FLOAT,   /* IEEE 754 binary64                                         */
    V_BOOL,
    V_NIL,     /* absence, and nothing else                                 */
    V_ERROR    /* internal: a failure already reported, propagating quietly  */
} VKind;

typedef struct Value Value;
struct Value {
    VKind         kind;
    const char   *type;    /* V_NODE: its name                             */
    const char   *text;    /* V_TEXT: its bytes                            */
    size_t        len;

    /* Where this came from: the first byte of its first token, and the last
     * byte of its last. A node is a **stretch** of source and not a point,
     * which matters wherever something is emitted *after* the things it is
     * about -- a send's own bytes go in after its arguments, so the line they
     * belong to is where the argument list ends. */
    size_t        pos;
    size_t        endpos;
    const char  **fields;  /* V_NODE: one name per kid, or NULL throughout  */
    Value       **items;
    int           n;
    long long     ival;    /* V_INT, V_BOOL                                */
    double        real;    /* V_FLOAT                                      */
    void         *attrs;   /* V_NODE: what a pass has worked out about it  */
};

/* ------------------------------------------------------------------ */
/* Evaluating an expression
 *
 * One evaluator, used by both halves. A stage-1 action resolves `$2` against
 * the factors of a sequence; a stage-2 clause resolves `$name` against what its
 * pattern bound. Everything between those two ends -- the arithmetic, the
 * comparisons, the formatting -- is the same code, because two evaluators of
 * one notation would be two things to keep in agreement and the project has
 * enough of those already.
 */

typedef struct Eval Eval;
struct Eval {
    Arena         *a;
    const Grammar *g;
    Value       *(*ref)(Eval *, const Expr *);   /* $n, $name, $$, x.attr   */
    void          *data;                          /* whatever ref needs      */
    size_t         pos;   /* where in the *source* a node built here belongs */
    size_t         endpos;/* and where it ends -- see Value.endpos           */
};

Value *eval_expr(Eval *e, const Expr *x);

/* The functions a pass may call -- library.c, kept separate so that the
 * question of where the library stops stays a visible one. */
Value *eval_call(Eval *e, const Expr *x);

Value *value_int(Arena *a, long long n);
Value *value_float(Arena *a, double d);
Value *value_bool(Arena *a, bool b);
Value *value_nil(Arena *a);

/* A failure that has already been reported. Every operation on one answers
 * another, silently -- so one mistake in a pass produces one message rather
 * than one message and four consequences of it. */
Value *value_error(Arena *a);
bool   value_failed(const Value *v);
Value *value_text(Arena *a, const char *text, size_t len);

/* Writes a value the way `of` writes it -- see docs/semantics.md. Answers
 * false, having reported, for the kinds that refuse to be written. */
bool value_format(Arena *a, const Value *v, char **out, size_t *len);

const char *value_kind_name(const Value *v);

/* Structural equality -- the same `=` answers, so that everything comparing
 * values compares them the one way. */
bool value_equal(const Value *a, const Value *b);

/* Matches the tokens against the grammar. Answers NULL on a syntax error,
 * having reported where the match got furthest and what it wanted there. */
Value *parse_run(Arena *a, const Grammar *g, const Source *src, const Tokens *t);

/* ------------------------------------------------------------------ */
/* A target language's own includes -- include.c
 *
 * `%import` splices one description into another. This is the same thing one
 * level down, for the language being described, and it is a separate mechanism
 * for a reason that is not arbitrary: **a pass cannot do it.** A pass is a walk
 * over one tree that has already been read, and an include is a second file
 * that has to be read before there is a tree to walk at all.
 *
 * So this runs between the parser and the first pass, and every pass after it
 * sees one tree that never mentions a second file.
 */

typedef struct {
    const char **dirs;
    int          n;
    int          cap;
} IncludePath;

/* `-I dir`, in the order given: the first directory holding a file wins. */
void include_path_add(Arena *a, IncludePath *look, const char *dir);

/* Replaces every include node in `root` with what the file it names holds.
 * `src` grows as files are read, so that a position in an included file still
 * names its own file and line; the tree is edited in place. Answers false
 * having reported. Does nothing at all when the description declares no
 * `%include`. */
bool include_expand(Arena *a, const Grammar *g, Source *src,
                    const IncludePath *look, Value *root);

/* ------------------------------------------------------------------ */
/* Counting the work
 *
 * A PEG with no memoisation can do more work than there is input, and how much
 * more is a property of the grammar rather than of the machine. These say how
 * much was actually done, so that a curve can be explained and not merely
 * drawn: `steps` is one attempt to match one grammar node at one position.
 */

typedef struct {
    long long lex_steps;     /* attempts in the scanner   */
    long long parse_steps;   /* attempts in the matcher   */
    long long nodes;         /* values the tree came to   */
    int       depth;         /* how deep the matcher went */
} Work;

const Work *work_done(void);
void        work_reset(void);

void tree_dump(FILE *out, const Value *root);

/* ------------------------------------------------------------------ */
/* Running a pass -- run.c */

const Pass   *pass_find(const Grammar *g, const char *name);
const Driver *driver_find(const Grammar *g, const char *name);

/* The driver to run when none is named: the first one declared in the file
 * that was asked for, and only failing that the first declared anywhere. A
 * description that imports another must not inherit its default -- the file
 * you named is the one that says what it is for. */
const Driver *driver_default(const Grammar *g);

/* One walk, post-order. Answers false having reported. */
bool pass_run(Arena *a, const Grammar *g, const Source *src,
              const Pass *pass, Value *root);

/* What a pass worked out about a node, or NULL. */
Value *pass_attr(const Value *node, const char *name);

const Rewrite *rewrite_find(const Grammar *g, const char *name);

/* One walk, replacing. The root itself may be replaced, which is why the tree
 * arrives by reference. Answers false having reported. */
bool rewrite_run(Arena *a, const Grammar *g, const Source *src,
                 const Rewrite *rw, Value **root);

/* One stage of a driver, whichever kind it is. Answers false having reported;
 * `*root` is what the next stage should walk. */
bool driver_stage(Arena *a, const Grammar *g, const Source *src,
                  const char *name, Value **root);

/* ------------------------------------------------------------------ */
/* Writing a description out as its own compiler -- emit.c */

bool emit_compiler(const Grammar *g, const char *name, FILE *out);

#endif /* PHX_H */
