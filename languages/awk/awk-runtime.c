/* ---- the awk runtime, emitted by languages/awk/awk-c.phx ---- */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <math.h>
#include <regex.h>
#include <time.h>

/* A value is a string and a number at once, which is the whole of awk's type
   system. `isnum` says the number is the one to use; `strnum` says the string
   came from input and looked like a number, so a comparison treats it as one. */
typedef struct Map Map;
typedef struct { char *s; double n; int isnum, strnum; Map *map; } Cell;

static void *xmalloc(size_t n) {
    void *p = malloc(n);
    if (!p) { fputs("awk: out of memory\n", stderr); exit(2); }
    return p;
}
static char *dup_str(const char *s) { char *p = xmalloc(strlen(s)+1); strcpy(p, s); return p; }

static Cell mkstr(const char *s) { Cell c; c.s = dup_str(s); c.n = 0; c.isnum = 0; c.strnum = 0; c.map = 0; return c; }
static Cell mknum(double d)      { Cell c; c.s = 0; c.n = d; c.isnum = 1; c.strnum = 0; c.map = 0; return c; }
static Cell uninit(void)         { Cell c; c.s = dup_str(""); c.n = 0; c.isnum = 1; c.strnum = 1; c.map = 0; return c; }

/* Does this text look like a number all the way through? That is what makes a
   field compare as a number rather than as text. */
static int looks_numeric(const char *s, double *out) {
    char *end; const char *p = s;
    while (isspace((unsigned char)*p)) p++;
    if (!*p) return 0;
    double d = strtod(p, &end);
    if (end == p) return 0;
    while (isspace((unsigned char)*end)) end++;
    if (*end) return 0;
    if (out) *out = d;
    return 1;
}

static Cell mkinput(const char *s) {
    Cell c = mkstr(s);
    double d;
    if (looks_numeric(s, &d)) { c.n = d; c.strnum = 1; }
    return c;
}

static char *CONVFMT = "%.6g";
static char *OFMT    = "%.6g";

/* A number's text: an integer has no decimal point whatever CONVFMT says,
   which is the rule that makes `print 1+1` say 2. */
static char *num_to_str(double d, const char *fmt) {
    char buf[64];
    if (d == (long long)d && fabs(d) < 1e18) snprintf(buf, sizeof buf, "%lld", (long long)d);
    else snprintf(buf, sizeof buf, fmt, d);
    return dup_str(buf);
}
static const char *to_str(Cell *c) {
    if (!c->s) c->s = num_to_str(c->n, CONVFMT);
    return c->s;
}
static const char *to_out(Cell *c) {   /* what `print` writes: OFMT, not CONVFMT */
    if (c->isnum && !c->strnum) return num_to_str(c->n, OFMT);
    return to_str(c);
}
static double to_num(Cell *c) {
    if (c->isnum || c->strnum) return c->n;
    double d = 0; looks_numeric(c->s, &d);
    if (!d) { char *e; d = strtod(c->s ? c->s : "", &e); }
    return d;
}
static int truthy(Cell *c) {
    if (c->isnum || c->strnum) return to_num(c) != 0;
    return c->s && c->s[0];
}

/* POSIX: numeric when both sides are numbers, or came from input looking like
   one, or were never set. Otherwise the strings are compared. */
static int numericish(Cell *c) { return c->isnum || c->strnum; }
static int cmp_cells(Cell *a, Cell *b) {
    if (numericish(a) && numericish(b)) {
        double x = to_num(a), y = to_num(b);
        return x < y ? -1 : x > y ? 1 : 0;
    }
    return strcmp(to_str(a), to_str(b));
}
static Cell cat_cells(Cell *a, Cell *b) {
    const char *x = to_str(a), *y = to_str(b);
    char *p = xmalloc(strlen(x) + strlen(y) + 1);
    strcpy(p, x); strcat(p, y);
    Cell c; c.s = p; c.n = 0; c.isnum = 0; c.strnum = 0; c.map = 0; return c;
}

/* ---- regular expressions ----
   Compiled once and kept, because a pattern in a loop is the common case and
   `regcomp` is not cheap. */
typedef struct RE { char *pat; regex_t re; struct RE *next; } RE;
static RE *RECACHE = 0;

static regex_t *re_get(const char *pat) {
    for (RE *r = RECACHE; r; r = r->next) if (strcmp(r->pat, pat) == 0) return &r->re;
    RE *r = xmalloc(sizeof *r);
    r->pat = dup_str(pat);
    if (regcomp(&r->re, pat, REG_EXTENDED) != 0) {
        fprintf(stderr, "awk: cannot compile regular expression /%s/\n", pat);
        exit(2);
    }
    r->next = RECACHE; RECACHE = r;
    return &r->re;
}
static double RSTART = 0, RLENGTH = -1;

static int re_find(const char *s, const char *pat, int *start, int *len) {
    regmatch_t m;
    if (regexec(re_get(pat), s, 1, &m, 0) != 0) return 0;
    if (start) *start = (int)m.rm_so;
    if (len)   *len   = (int)(m.rm_eo - m.rm_so);
    return 1;
}

/* ---- the record, and its fields ---- */

static char  *RECORD = 0;
static FILE  *INPUT = 0;
static double FNR = 0;
static char  *FILENAME = "";
static Cell  *FIELD  = 0;
static int    NFIELD = 0, FIELDCAP = 0;
static double NR = 0, NF = 0;
static char  *FS = " ", *OFS = " ", *ORS = "\n";

static void split_record(void) {
    NFIELD = 0;
    const char *p = RECORD;
    if (FS[0] == ' ' && FS[1] == 0) {
        for (;;) {
            while (*p == ' ' || *p == '\t' || *p == '\n') p++;
            if (!*p) break;
            const char *start = p;
            while (*p && *p != ' ' && *p != '\t' && *p != '\n') p++;
            if (NFIELD == FIELDCAP) {
                FIELDCAP = FIELDCAP ? FIELDCAP * 2 : 16;
                FIELD = realloc(FIELD, (size_t)FIELDCAP * sizeof *FIELD);
                if (!FIELD) { fputs("awk: out of memory\n", stderr); exit(2); }
            }
            char *t = xmalloc((size_t)(p - start) + 1);
            memcpy(t, start, (size_t)(p - start)); t[p - start] = 0;
            FIELD[NFIELD++] = mkinput(t);
        }
    } else if (FS[1]) {
        /* More than one character is a regular expression, which is what
           `FS = "[:,]"` means and what one-true-awk does with it. */
        for (;;) {
            int at = 0, len = 0;
            int found = re_find(p, FS, &at, &len) && len > 0;
            int cut = found ? at : (int)strlen(p);
            if (NFIELD == FIELDCAP) {
                FIELDCAP = FIELDCAP ? FIELDCAP * 2 : 16;
                FIELD = realloc(FIELD, (size_t)FIELDCAP * sizeof *FIELD);
                if (!FIELD) { fputs("awk: out of memory\n", stderr); exit(2); }
            }
            char *t = xmalloc((size_t)cut + 1);
            memcpy(t, p, (size_t)cut); t[cut] = 0;
            FIELD[NFIELD++] = mkinput(t);
            if (!found) break;
            p += cut + len;
        }
    } else {
        for (;;) {
            const char *start = p;
            while (*p && *p != FS[0]) p++;
            if (NFIELD == FIELDCAP) {
                FIELDCAP = FIELDCAP ? FIELDCAP * 2 : 16;
                FIELD = realloc(FIELD, (size_t)FIELDCAP * sizeof *FIELD);
                if (!FIELD) { fputs("awk: out of memory\n", stderr); exit(2); }
            }
            char *t = xmalloc((size_t)(p - start) + 1);
            memcpy(t, start, (size_t)(p - start)); t[p - start] = 0;
            FIELD[NFIELD++] = mkinput(t);
            if (!*p) break;
            p++;
        }
    }
    NF = NFIELD;
}

static int next_file(void);

static int next_record(void) {
    static char *line = 0; static size_t cap = 0;
    extern FILE *INPUT;
    for (;;) {
        if (!INPUT && !next_file()) return 0;
        size_t len = 0;
        int ch, any = 0;
        for (;;) {
            ch = getc(INPUT);
            if (ch == EOF) break;
            any = 1;
            if (ch == '\n') break;
            if (len + 1 >= cap) { cap = cap ? cap * 2 : 128; line = realloc(line, cap); }
            line[len++] = (char)ch;
        }
        if (!any) { if (INPUT != stdin) fclose(INPUT); INPUT = 0; continue; }
        if (len + 1 >= cap) { cap = cap ? cap * 2 : 128; line = realloc(line, cap); }
        line[len] = 0;
        RECORD = dup_str(line);
        NR++; FNR++;
        split_record();
        return 1;
    }
}

static Cell get_field(double which) {
    int i = (int)which;
    if (i == 0) return mkinput(RECORD ? RECORD : "");
    if (i < 1 || i > NFIELD) return uninit();
    return FIELD[i - 1];
}

/* ---- output ---- */

static void awk_fprint(FILE *f, Cell *a, int n) {
    for (int i = 0; i < n; i++) {
        if (i) fputs(OFS, f);
        fputs(to_out(&a[i]), f);
    }
    fputs(ORS, f);
}
static void awk_print(Cell *a, int n) { awk_fprint(stdout, a, n); }

/* awk's printf: the format is walked and each conversion takes the next value
   as whatever that conversion wants. */
typedef struct { char *p; size_t at, cap; } Buf;
static void buf_need(Buf *b, size_t n) {
    if (b->p && b->at + n + 1 < b->cap) return;
    b->cap = (b->cap + n + 1) * 2;
    b->p = realloc(b->p, b->cap);
    if (!b->p) { fputs("awk: out of memory\n", stderr); exit(2); }
}
static void buf_put(Buf *b, const char *s) { size_t n = strlen(s); buf_need(b, n); memcpy(b->p + b->at, s, n); b->at += n; }
static void buf_ch(Buf *b, char c) { buf_need(b, 1); b->p[b->at++] = c; }

/* One formatter, so that `printf` and `sprintf` cannot disagree about a
   format. Each conversion takes the next value as whatever it wants. */
static char *format_with(Cell *fmt, Cell *a, int n) {
    const char *f = to_str(fmt);
    Buf b = { 0, 0, 0 };
    char spec[64], piece[512];
    int at = 0;
    buf_need(&b, 16);
    while (*f) {
        if (*f != '%') { buf_ch(&b, *f++); continue; }
        if (f[1] == '%') { buf_ch(&b, '%'); f += 2; continue; }
        size_t k = 0;
        spec[k++] = *f++;
        while (*f && !strchr("diouxXeEfgGcs", *f) && k < sizeof spec - 4) spec[k++] = *f++;
        if (!*f) break;
        char conv = *f++;
        Cell nothing = uninit();
        Cell *v = at < n ? &a[at++] : &nothing;
        switch (conv) {
        case 'd': case 'i':
            spec[k] = 'l'; spec[k+1] = 'l'; spec[k+2] = 'd'; spec[k+3] = 0;
            snprintf(piece, sizeof piece, spec, (long long)to_num(v)); break;
        case 'o': case 'u': case 'x': case 'X':
            spec[k] = 'l'; spec[k+1] = 'l'; spec[k+2] = conv; spec[k+3] = 0;
            snprintf(piece, sizeof piece, spec, (long long)to_num(v)); break;
        case 'e': case 'E': case 'f': case 'g': case 'G':
            spec[k] = conv; spec[k+1] = 0;
            snprintf(piece, sizeof piece, spec, to_num(v)); break;
        case 'c': {
            spec[k] = 'c'; spec[k+1] = 0;
            int ch;
            if (v->isnum && !v->s) ch = (int)to_num(v);
            else { const char *t = to_str(v); ch = t[0] ? (unsigned char)t[0] : ' '; }
            snprintf(piece, sizeof piece, spec, ch); break;
        }
        default:
            spec[k] = 's'; spec[k+1] = 0;
            snprintf(piece, sizeof piece, spec, to_str(v)); break;
        }
        buf_put(&b, piece);
    }
    buf_need(&b, 1); b.p[b.at] = 0;
    return b.p;
}
static void awk_fprintf(FILE *f, Cell *fmt, Cell *a, int n) { fputs(format_with(fmt, a, n), f); }
static void awk_printf(Cell *fmt, Cell *a, int n) { awk_fprintf(stdout, fmt, a, n); }



/* ---- what emitted code calls ----
   Every expression in a compiled program is a `Cell`, and these take one by
   value so that the emitter never has to name a temporary. */
static double      num_of(Cell c)         { return to_num(&c); }
static const char *str_of(Cell c)         { return to_str(&c); }
static int         truth_of(Cell c)       { return truthy(&c); }
static int         cmp_of(Cell a, Cell b) { return cmp_cells(&a, &b); }
static Cell        cat_of(Cell a, Cell b) { return cat_cells(&a, &b); }
static Cell        fld_of(Cell i)         { return get_field(to_num(&i)); }

static int re_matches(Cell s, Cell pat) { return re_find(str_of(s), str_of(pat), 0, 0); }
static Cell re_match_at(Cell s, Cell pat) {
    int start, len;
    if (!re_find(str_of(s), str_of(pat), &start, &len)) { RSTART = 0; RLENGTH = -1; return mknum(0); }
    RSTART = start + 1; RLENGTH = len;
    return mknum(RSTART);
}

static double div_by(double a, double b) {
    if (b == 0) { fputs("awk: division by zero\n", stderr); exit(2); }
    return a / b;
}
static double mod_by(double a, double b) {
    if (b == 0) { fputs("awk: division by zero in %\n", stderr); exit(2); }
    return fmod(a, b);
}

static Cell post_step(Cell *v, double by) {
    double old = to_num(v);
    *v = mknum(old + by);
    return mknum(old);
}
static Cell pre_step(Cell *v, double by) {
    *v = mknum(to_num(v) + by);
    return *v;
}
static Cell assign_str(char **slot, Cell v) { *slot = dup_str(to_str(&v)); return v; }

/* ---- arrays ----
   awk has one aggregate and it is a hash from strings to values. A variable
   becomes one by being subscripted, which is why the map hangs off a `Cell`
   rather than being a kind of its own. */
typedef struct Slot { char *key; Cell val; struct Slot *next; } Slot;
struct Map { Slot **b; int cap, n; };

static char *SUBSEP = "\034";

static unsigned hash_of(const char *s) {
    unsigned h = 2166136261u;
    while (*s) { h ^= (unsigned char)*s++; h *= 16777619u; }
    return h;
}
static Map *new_map(void) {
    Map *m = xmalloc(sizeof *m);
    m->cap = 64; m->n = 0;
    m->b = xmalloc((size_t)m->cap * sizeof *m->b);
    for (int i = 0; i < m->cap; i++) m->b[i] = 0;
    return m;
}
static Map *arr_of(Cell *v) { if (!v->map) v->map = new_map(); return v->map; }

static Slot *map_find(Map *m, const char *k) {
    for (Slot *s = m->b[hash_of(k) % (unsigned)m->cap]; s; s = s->next)
        if (strcmp(s->key, k) == 0) return s;
    return 0;
}
static int map_has(Map *m, const char *k) { return map_find(m, k) != 0; }

/* Reading `a[k]` creates the element, which is what awk does and what makes
   `if (a[k] == "")` grow the array. `in` is the question that does not. */
static Cell *map_at(Map *m, const char *k) {
    Slot *s = map_find(m, k);
    if (s) return &s->val;
    unsigned i = hash_of(k) % (unsigned)m->cap;
    s = xmalloc(sizeof *s);
    s->key = dup_str(k); s->val = uninit(); s->next = m->b[i];
    m->b[i] = s; m->n++;
    return &s->val;
}
static void map_del(Map *m, const char *k) {
    unsigned i = hash_of(k) % (unsigned)m->cap;
    Slot **p = &m->b[i];
    while (*p) { if (strcmp((*p)->key, k) == 0) { *p = (*p)->next; m->n--; return; } p = &(*p)->next; }
}
static void map_clear(Map *m) {
    for (int i = 0; i < m->cap; i++) m->b[i] = 0;
    m->n = 0;
}
static int map_keys(Map *m, char ***out) {
    char **k = xmalloc((size_t)(m->n ? m->n : 1) * sizeof *k);
    int at = 0;
    for (int i = 0; i < m->cap; i++)
        for (Slot *s = m->b[i]; s; s = s->next) k[at++] = s->key;
    *out = k;
    return at;
}
/* `a[i, j]` is one key with SUBSEP between the parts, which is how awk gets a
   multi-dimensional array out of a one-dimensional one. */
static Cell subsep_join(Cell a, Cell b) {
    Cell sep = mkstr(SUBSEP);
    Cell left = cat_cells(&a, &sep);
    return cat_cells(&left, &b);
}

/* ---- the record, written to ---- */

static void rebuild_record(void) {
    size_t total = 0;
    for (int i = 0; i < NFIELD; i++) total += strlen(to_str(&FIELD[i])) + strlen(OFS);
    char *p = xmalloc(total + 1); p[0] = 0;
    for (int i = 0; i < NFIELD; i++) {
        if (i) strcat(p, OFS);
        strcat(p, to_str(&FIELD[i]));
    }
    RECORD = p;
}
static void set_record(const char *s) { RECORD = dup_str(s); split_record(); }

static Cell set_field(double which, Cell v) {
    int i = (int)which;
    if (i == 0) { set_record(to_str(&v)); return v; }
    while (NFIELD < i) {
        if (NFIELD == FIELDCAP) {
            FIELDCAP = FIELDCAP ? FIELDCAP * 2 : 16;
            FIELD = realloc(FIELD, (size_t)FIELDCAP * sizeof *FIELD);
            if (!FIELD) { fputs("awk: out of memory\n", stderr); exit(2); }
        }
        FIELD[NFIELD++] = uninit();
    }
    NF = NFIELD;
    FIELD[i - 1] = v;
    rebuild_record();
    return v;
}

/* ---- the string builtins ---- */

static Cell awk_substr(Cell s, Cell m, Cell n, int have_n) {
    const char *t = str_of(s);
    long len = (long)strlen(t);
    long from = (long)(to_num(&m) + 0.5), count = have_n ? (long)(to_num(&n) + 0.5) : len;
    /* The start is clamped to 1 and *then* the count is taken, which is what
       one-true-awk does: substr("abc", 0, 2) is "ab" and not "a". */
    long start = from < 1 ? 1 : from;
    long end = start + count;           /* one past the last, in awk's numbering */
    if (end > len + 1) end = len + 1;
    if (end <= start) return mkstr("");
    char *p = xmalloc((size_t)(end - start) + 1);
    memcpy(p, t + start - 1, (size_t)(end - start)); p[end - start] = 0;
    Cell c = mkstr(p); return c;
}
static Cell awk_index(Cell s, Cell t) {
    const char *a = str_of(s), *b = str_of(t);
    const char *at = strstr(a, b);
    return mknum(at ? (double)(at - a) + 1 : 0);
}
static Cell awk_toupper(Cell s) {
    char *p = dup_str(str_of(s));
    for (char *q = p; *q; q++) *q = (char)toupper((unsigned char)*q);
    return mkstr(p);
}
static Cell awk_tolower(Cell s) {
    char *p = dup_str(str_of(s));
    for (char *q = p; *q; q++) *q = (char)tolower((unsigned char)*q);
    return mkstr(p);
}
static Cell awk_sprintf(Cell *a, int n);

/* `split` fills an array and answers how many parts there were. */
static Cell awk_split(Cell s, Cell *arr, Cell fs, int have_fs) {
    Map *m = arr_of(arr);
    map_clear(m);
    const char *t = str_of(s);
    const char *sep = have_fs ? str_of(fs) : FS;
    int count = 0;
    char key[32];

    if (!*t) return mknum(0);
    if (sep[0] == ' ' && sep[1] == 0) {
        const char *p = t;
        for (;;) {
            while (*p == ' ' || *p == '\t' || *p == '\n') p++;
            if (!*p) break;
            const char *start = p;
            while (*p && *p != ' ' && *p != '\t' && *p != '\n') p++;
            char *w = xmalloc((size_t)(p - start) + 1);
            memcpy(w, start, (size_t)(p - start)); w[p - start] = 0;
            snprintf(key, sizeof key, "%d", ++count);
            *map_at(m, key) = mkinput(w);
        }
        return mknum(count);
    }
    /* A separator of one character is that character; anything longer is a
       regular expression, which is what awk says and what FS usually is. */
    const char *p = t;
    for (;;) {
        int start = 0, len = 0;
        int found = sep[1] && re_find(p, sep, &start, &len) && len > 0;
        int cut = found ? start : (int)strlen(p);
        if (!found && sep[1] == 0) {
            const char *hit = strchr(p, sep[0]);
            cut = hit ? (int)(hit - p) : (int)strlen(p);
            found = hit != 0; len = 1;
        }
        char *w = xmalloc((size_t)cut + 1);
        memcpy(w, p, (size_t)cut); w[cut] = 0;
        snprintf(key, sizeof key, "%d", ++count);
        *map_at(m, key) = mkinput(w);
        if (!found) break;
        p += cut + len;
    }
    return mknum(count);
}

/* `sub` and `gsub` write through their target, and `&` in the replacement is
   whatever matched. */
static Cell awk_sub(Cell re, Cell repl, Cell *target, int global) {
    const char *s = to_str(target), *pat = str_of(re), *r = str_of(repl);
    size_t cap = strlen(s) * 2 + strlen(r) * 4 + 64;
    char *out = xmalloc(cap); size_t at = 0;
    int count = 0;
    const char *p = s;

    for (;;) {
        int start, len;
        if (!re_find(p, pat, &start, &len)) break;
        if (at + (size_t)start + 2 >= cap) { cap = cap * 2 + (size_t)start; out = realloc(out, cap); }
        memcpy(out + at, p, (size_t)start); at += (size_t)start;
        for (const char *q = r; *q; q++) {
            if (at + (size_t)len + 4 >= cap) { cap = cap * 2 + (size_t)len; out = realloc(out, cap); }
            if (*q == '\\' && q[1] == '&') { out[at++] = '&'; q++; }
            else if (*q == '&') { memcpy(out + at, p + start, (size_t)len); at += (size_t)len; }
            else out[at++] = *q;
        }
        count++;
        p += start + len;
        if (len == 0) { if (!*p) break; out[at++] = *p++; }
        if (!global) break;
    }
    size_t rest = strlen(p);
    if (at + rest + 1 >= cap) { cap = at + rest + 2; out = realloc(out, cap); }
    memcpy(out + at, p, rest); out[at + rest] = 0;
    if (count) *target = mkstr(out);
    return mknum(count);
}

static Cell awk_sprintf(Cell *a, int n) {
    return mkstr(format_with(&a[0], a + 1, n));
}

/* ---- what stage two's emitted code calls ---- */

static Cell  *elem_of(Cell *v, Cell k)      { return map_at(arr_of(v), str_of(k)); }
static Cell   has_elem(Cell *v, Cell k)     { return mknum(map_has(arr_of(v), str_of(k))); }
static void   del_elem(Cell *v, Cell k)     { map_del(arr_of(v), str_of(k)); }
static void   del_all(Cell *v)              { map_clear(arr_of(v)); }
static Cell   sub_join(Cell a, Cell b)      { return subsep_join(a, b); }
static Cell   re_test(Cell s, Cell p)       { return mknum(re_matches(s, p)); }
static Cell   re_ntest(Cell s, Cell p)      { return mknum(!re_matches(s, p)); }
static Cell   fld_set(Cell i, Cell v)       { return set_field(to_num(&i), v); }

static Cell math1(double (*f)(double), Cell x) { return mknum(f(to_num(&x))); }
static Cell awk_rand(void)  { return mknum((double)rand() / ((double)RAND_MAX + 1.0)); }
static Cell awk_srand(Cell s, int have) {
    static double prev = 0;
    double was = prev;
    prev = have ? to_num(&s) : (double)time(0);
    srand((unsigned)prev);
    return mknum(was);
}

/* `a[i, j]` -- the parts arrive as an array because the emitter has no way to
   fold a list into nested calls, and this is the fold. */
static Cell key_of(Cell *parts, int n) {
    Cell k = parts[0];
    for (int i = 1; i < n; i++) k = subsep_join(k, parts[i]);
    return k;
}

/* A function's parameters beyond what the call gave are its locals, so a call
   passes what it has and the body asks for what it wants. */
static Cell arg_at(Cell *a, int n, int i) { return i < n ? a[i] : uninit(); }

/* An array is passed by reference and a scalar by value, and awk decides which
   by what the callee does. Making the map before the call means a variable
   used as an array inside is the caller's array, whichever way it is used. */
static Cell arr_ready(Cell *v) { arr_of(v); return *v; }

/* ---- where output goes ----
   A name is a file or a command; either way it stays open until `close` or
   the end, because awk's `print > "f"` appends to what it already opened. */
typedef struct Out { char *name; FILE *f; int is_pipe; struct Out *next; } Out;
static Out *OUTS = 0;

static FILE *out_for(const char *name, const char *mode, int is_pipe) {
    for (Out *o = OUTS; o; o = o->next)
        if (o->is_pipe == is_pipe && strcmp(o->name, name) == 0) return o->f;
    FILE *f = is_pipe ? popen(name, "w") : fopen(name, mode);
    if (!f) { fprintf(stderr, "awk: cannot open %s\n", name); exit(2); }
    Out *o = xmalloc(sizeof *o);
    o->name = dup_str(name); o->f = f; o->is_pipe = is_pipe; o->next = OUTS;
    OUTS = o;
    return f;
}
static FILE *file_out(Cell n)   { return out_for(str_of(n), "w", 0); }
static FILE *file_app(Cell n)   { return out_for(str_of(n), "a", 0); }
static FILE *pipe_out(Cell n)   { return out_for(str_of(n), "w", 1); }

static Cell awk_close(Cell name) {
    const char *n = str_of(name);
    Out **p = &OUTS;
    while (*p) {
        if (strcmp((*p)->name, n) == 0) {
            int r = (*p)->is_pipe ? pclose((*p)->f) : fclose((*p)->f);
            *p = (*p)->next;
            return mknum(r);
        }
        p = &(*p)->next;
    }
    return mknum(-1);
}
static void close_all(void) {
    for (Out *o = OUTS; o; o = o->next) { if (o->is_pipe) pclose(o->f); else fclose(o->f); }
    OUTS = 0;
}
static Cell awk_system(Cell cmd) { fflush(0); return mknum(system(str_of(cmd)) / 256); }
static Cell awk_fflush(void)     { fflush(0); return mknum(0); }

/* ---- the input, which is the files named on the command line ---- */

static char **ARGF = 0;
static int    ARGFN = 0, ARGFAT = 0;

/* A `name=value` operand is an assignment made when the reader reaches it, not
   at the start -- which is what lets `awk '{...}' n=1 a.txt n=2 b.txt` work. */
typedef struct { const char *name; Cell *slot; } Global;
static Global *GLOBALS = 0;
static int NGLOBALS = 0;

static int assign_arg(const char *s) {
    const char *eq = strchr(s, '=');
    if (!eq || eq == s) return 0;
    for (const char *p = s; p < eq; p++)
        if (!isalnum((unsigned char)*p) && *p != '_') return 0;
    for (int i = 0; i < NGLOBALS; i++)
        if ((int)strlen(GLOBALS[i].name) == eq - s
            && memcmp(GLOBALS[i].name, s, (size_t)(eq - s)) == 0) {
            *GLOBALS[i].slot = mkinput(eq + 1);
            return 1;
        }
    return 1;                       /* a name the program never mentions */
}

static int next_file(void) {
    while (ARGFAT < ARGFN) {
        char *a = ARGF[ARGFAT++];
        if (assign_arg(a)) continue;
        INPUT = strcmp(a, "-") == 0 ? stdin : fopen(a, "r");
        if (!INPUT) { fprintf(stderr, "awk: can't open file %s\n", a); exit(2); }
        FILENAME = a; FNR = 0;
        return 1;
    }
    if (ARGFN == 0 && !INPUT && ARGFAT == 0) { ARGFAT = 1; INPUT = stdin; return 1; }
    return 0;
}

/* `-v name=value` is applied before BEGIN; a bare `name=value` among the files
   is applied when the reader reaches it. Same syntax, different moment, which
   is awk's rule and the reason both exist. */
static int take_options(int argc, char **argv) {
    int i = 1;
    while (i < argc && strcmp(argv[i], "-v") == 0 && i + 1 < argc) {
        assign_arg(argv[i + 1]);
        i += 2;
    }
    return i;
}
static void input_from(int argc, char **argv, int at) {
    ARGF = argv + at; ARGFN = argc - at; ARGFAT = 0;
}

/* `sub(re, repl)` with no third argument works on the record, which means
   writing it back and splitting it again. */
static Cell awk_sub0(Cell re, Cell repl, int global) {
    Cell t = mkinput(RECORD ? RECORD : "");
    Cell n = awk_sub(re, repl, &t, global);
    if (to_num(&n) > 0) set_record(to_str(&t));
    return n;
}
