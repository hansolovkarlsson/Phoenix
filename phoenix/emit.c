/* emit.c -- write a description out as a C program that is its compiler.
 *
 * ---------------------------------------------------------------------------
 * Tables, not code, and the reason is the one this project keeps returning to
 *
 * A generator has two ways to produce a compiler. It can **emit code** -- a
 * recursive-descent function per rule, a switch per pass -- which is faster and
 * is what most of the yacc family does. Or it can **emit the description as
 * data** and ship the machine that already runs it.
 *
 * Phoenix emits data, because the alternative is a second implementation of
 * everything: a second matcher with the same ordered-choice rules, a second
 * evaluator with the same floored division, a second pattern matcher. Two
 * implementations of one notation have to agree, and this project has spent
 * its whole life avoiding exactly that -- it is why actions are not host-
 * language splices and why docs/semantics.md exists.
 *
 * So the generated compiler runs **the same lex.c, parse.c, eval.c and run.c**
 * that `phx` runs, over a grammar frozen into static tables. There is nothing
 * for the two to disagree about, because there is only one of them. A
 * conformance test between `phx --run` and the generated compiler cannot fail
 * for an interesting reason, which is the point.
 *
 * What it costs is speed: the generated compiler interprets a PEG rather than
 * being one. That is a real cost and a measurable one, and if it ever matters
 * the answer is to compile the tables to code *afterwards*, against a
 * definition that is already pinned down by the tables.
 *
 * ---------------------------------------------------------------------------
 * How the tables are written
 *
 * Every tree -- grammar nodes, patterns, expressions -- is emitted in
 * **post-order**, so that a node's children are already declared as static
 * variables by the time the node naming them is. No forward declarations, no
 * fix-up pass, and the C compiler checks the shape on the way past.
 */
#include "phx.h"
#include "runtime.h"

#include <string.h>

typedef struct {
    FILE          *out;
    const Grammar *g;
    int            next;      /* the counter behind every generated name */
} Emit;

/* ------------------------------------------------------------------ */

static void emit_text(Emit *e, const char *s, size_t len)
{
    if (!s) { fputs("NULL", e->out); return; }

    fputc('"', e->out);
    for (size_t i = 0; i < len; i++) {
        unsigned char c = (unsigned char)s[i];
        switch (c) {
        case '"':  fputs("\\\"", e->out); break;
        case '\\': fputs("\\\\", e->out); break;
        case '\n': fputs("\\n",  e->out); break;
        case '\t': fputs("\\t",  e->out); break;
        case '\r': fputs("\\r",  e->out); break;
        default:
            if (c < 32 || c >= 127) fprintf(e->out, "\\%03o", c);
            else                    fputc((char)c, e->out);
        }
    }
    fputc('"', e->out);
}

static void emit_string(Emit *e, const char *s)
{
    emit_text(e, s, s ? strlen(s) : 0);
}

/* ------------------------------------------------------------------ */
/* Grammar nodes */

static int emit_expr(Emit *e, const Expr *x);

static int emit_gnode(Emit *e, const GNode *n)
{
    int kids[64];
    int nkids = n->nkids < 64 ? n->nkids : 64;

    for (int i = 0; i < nkids; i++) kids[i] = emit_gnode(e, n->kids[i]);

    /* What this alternative builds, if anything. Forgetting it is the one
     * mistake that produces a generated compiler which parses correctly and
     * answers nothing: the grammar is all there and every `->` has gone. */
    int action = n->action ? emit_expr(e, n->action) : -1;

    int id = e->next++;

    if (nkids) {
        fprintf(e->out, "static GNode *gk%d[] = {", id);
        for (int i = 0; i < nkids; i++) fprintf(e->out, "&g%d,", kids[i]);
        fputs("};\n", e->out);
    }

    fprintf(e->out, "static GNode g%d = {%d,", id, (int)n->kind);
    emit_string(e, n->text);   fputc(',', e->out);
    emit_string(e, n->upto);   fputc(',', e->out);
    emit_string(e, n->folded); fputc(',', e->out);
    fprintf(e->out, "%d,", n->len);
    if (nkids) fprintf(e->out, "gk%d,%d,", id, nkids);
    else       fputs("NULL,0,", e->out);
    fprintf(e->out, "%d,", n->ref);
    emit_string(e, n->label);
    if (action >= 0) fprintf(e->out, ",&x%d,%zu};\n", action, n->pos);
    else             fprintf(e->out, ",NULL,%zu};\n", n->pos);
    return id;
}

/* ------------------------------------------------------------------ */
/* Expressions */

static int emit_expr(Emit *e, const Expr *x)
{
    if (!x) return -1;

    int kids[64];
    int nkids = x->nkids < 64 ? x->nkids : 64;

    for (int i = 0; i < nkids; i++) kids[i] = emit_expr(e, x->kids[i]);

    int id = e->next++;

    if (nkids) {
        fprintf(e->out, "static Expr *xk%d[] = {", id);
        for (int i = 0; i < nkids; i++) fprintf(e->out, "&x%d,", kids[i]);
        fputs("};\n", e->out);

        fprintf(e->out, "static char *xf%d[] = {", id);
        for (int i = 0; i < nkids; i++) {
            emit_string(e, x->fields ? x->fields[i] : NULL);
            fputc(',', e->out);
        }
        fputs("};\n", e->out);
    }

    fprintf(e->out, "static Expr x%d = {%d,", id, (int)x->kind);
    emit_string(e, x->name);
    fprintf(e->out, ",%d,%d,%lldLL,", x->len, x->index, x->ival);
    fprintf(e->out, "%.17g,", x->real);
    if (nkids) fprintf(e->out, "xf%d,xk%d,%d,", id, id, nkids);
    else       fputs("NULL,NULL,0,", e->out);
    fprintf(e->out, "%zu};\n", x->pos);
    return id;
}

/* ------------------------------------------------------------------ */
/* Patterns */

static int emit_pattern(Emit *e, const Pattern *p)
{
    int kids[64];
    int nkids = p->nkids < 64 ? p->nkids : 64;

    for (int i = 0; i < nkids; i++) kids[i] = emit_pattern(e, p->kids[i]);

    int id = e->next++;

    if (nkids) {
        fprintf(e->out, "static Pattern *pk%d[] = {", id);
        for (int i = 0; i < nkids; i++) fprintf(e->out, "&p%d,", kids[i]);
        fputs("};\n", e->out);

        fprintf(e->out, "static char *pf%d[] = {", id);
        for (int i = 0; i < nkids; i++) {
            emit_string(e, p->fields[i]);
            fputc(',', e->out);
        }
        fputs("};\n", e->out);
    }

    fprintf(e->out, "static Pattern p%d = {%d,", id, (int)p->kind);
    emit_string(e, p->name);
    fprintf(e->out, ",%d,%lldLL,", p->len, p->ival);
    if (nkids) fprintf(e->out, "pf%d,pk%d,%d,", id, id, nkids);
    else       fputs("NULL,NULL,0,", e->out);
    fprintf(e->out, "%zu};\n", p->pos);
    return id;
}

/* ------------------------------------------------------------------ */

static void emit_rules(Emit *e)
{
    const Grammar *g = e->g;
    int *body = arena_alloc(g->arena, (size_t)(g->nrules ? g->nrules : 1) * sizeof *body);

    for (int i = 0; i < g->nrules; i++)
        body[i] = g->rules[i].body ? emit_gnode(e, g->rules[i].body) : -1;

    fputs("\nstatic Rule phx_rules[] = {\n", e->out);
    for (int i = 0; i < g->nrules; i++) {
        const Rule *r = &g->rules[i];
        fputs("  {", e->out);
        emit_string(e, r->name);
        if (body[i] >= 0) fprintf(e->out, ",&g%d,", body[i]);
        else              fputs(",NULL,", e->out);
        fprintf(e->out, "%d,%d,%d,%d,%d,%d,%zu},\n",
                r->lexical, r->fragment, r->skip, r->used, r->required,
                r->nullable, r->pos);
    }
    fputs("};\n", e->out);
}

static void emit_passes(Emit *e)
{
    const Grammar *g = e->g;

    for (int i = 0; i < g->npasses; i++) {
        const Pass *p = &g->passes[i];

        /* The ids are kept and written into the aggregate below rather than
         * through named pointers: a static initialiser in C may not name a
         * variable, only take the address of one. */
        int *initial = arena_alloc(e->g->arena,
                                   (size_t)(p->nthreads ? p->nthreads : 1) * sizeof *initial);
        for (int t = 0; t < p->nthreads; t++)
            initial[t] = emit_expr(e, p->initial[t]);

        if (p->nthreads) {
            fprintf(e->out, "static char *tn%d[] = {", i);
            for (int t = 0; t < p->nthreads; t++) {
                emit_string(e, p->threads[t]);
                fputc(',', e->out);
            }
            fputs("};\n", e->out);

            fprintf(e->out, "static Expr *tv%d[] = {", i);
            for (int t = 0; t < p->nthreads; t++)
                if (initial[t] >= 0) fprintf(e->out, "&x%d,", initial[t]);
                else                 fputs("NULL,", e->out);
            fputs("};\n", e->out);
        }

        for (int k = 0; k < p->nrules; k++) {
            const PassRule *pr = &p->rules[k];
            int pat = emit_pattern(e, pr->pattern);

            int *cv = arena_alloc(e->g->arena,
                                  (size_t)(pr->nclauses ? pr->nclauses : 1) * sizeof *cv);
            int *cw = arena_alloc(e->g->arena,
                                  (size_t)(pr->nclauses ? pr->nclauses : 1) * sizeof *cw);

            for (int m = 0; m < pr->nclauses; m++) {
                cv[m] = emit_expr(e, pr->clauses[m].value);
                cw[m] = emit_expr(e, pr->clauses[m].when);
            }

            fprintf(e->out, "static Clause cl%d_%d[] = {", i, k);
            for (int m = 0; m < pr->nclauses; m++) {
                const Clause *c = &pr->clauses[m];
                fprintf(e->out, "{%d,", (int)c->kind);
                emit_string(e, c->attr);
                fputc(',', e->out);
                if (cv[m] >= 0) fprintf(e->out, "&x%d,", cv[m]); else fputs("NULL,", e->out);
                if (cw[m] >= 0) fprintf(e->out, "&x%d,", cw[m]); else fputs("NULL,", e->out);
                fprintf(e->out, "%zu},", c->pos);
            }
            fputs("};\n", e->out);
            fprintf(e->out, "#define pp%d_%d (&p%d)\n", i, k, pat);
        }

        fprintf(e->out, "static PassRule pr%d[] = {", i);
        for (int k = 0; k < p->nrules; k++)
            fprintf(e->out, "{pp%d_%d,cl%d_%d,%d,%zu},",
                    i, k, i, k, p->rules[k].nclauses, p->rules[k].pos);
        fputs("};\n", e->out);
    }

    fputs("\nstatic Pass phx_passes[] = {\n", e->out);
    for (int i = 0; i < g->npasses; i++) {
        const Pass *p = &g->passes[i];
        fputs("  {", e->out);
        emit_string(e, p->name);
        if (p->nthreads) fprintf(e->out, ",tn%d,tv%d,%d,", i, i, p->nthreads);
        else             fputs(",NULL,NULL,0,", e->out);
        fprintf(e->out, "pr%d,%d,%zu},\n", i, p->nrules, p->pos);
    }
    fputs("};\n", e->out);
}

static void emit_drivers(Emit *e)
{
    const Grammar *g = e->g;

    for (int i = 0; i < g->ndrivers; i++) {
        const Driver *d = &g->drivers[i];
        fprintf(e->out, "static char *dp%d[] = {", i);
        for (int k = 0; k < d->npasses; k++) {
            emit_string(e, d->passes[k]);
            fputc(',', e->out);
        }
        fputs("};\n", e->out);

        fprintf(e->out, "static size_t dw%d[] = {", i);
        for (int k = 0; k < d->npasses; k++) fprintf(e->out, "%zu,", d->pass_pos[k]);
        fputs("};\n", e->out);
    }

    fputs("\nstatic Driver phx_drivers[] = {\n", e->out);
    for (int i = 0; i < g->ndrivers; i++) {
        const Driver *d = &g->drivers[i];
        fputs("  {", e->out);
        emit_string(e, d->name);
        fprintf(e->out, ",dp%d,%d,", i, d->npasses);
        emit_string(e, d->answer);
        fprintf(e->out, ",%zu,dw%d},\n", d->pos, i);
    }
    fputs("};\n", e->out);
}

/* ------------------------------------------------------------------ */

bool emit_compiler(const Grammar *g, const char *name, FILE *out)
{
    Emit e = { .out = out, .g = g, .next = 0 };

    fprintf(out,
        "/* %s -- a compiler, written by Phoenix. Do not edit.\n"
        " *\n"
        " * The description is frozen into the tables below and run by the same\n"
        " * matcher and evaluator `phx` uses -- included above, verbatim -- so\n"
        " * this program and `phx` cannot disagree about what the description\n"
        " * means. There is only one implementation of it and this file is its\n"
        " * data.\n"
        " *\n"
        " * One file, no headers, no library:  cc %s -o a-compiler\n"
        " */\n", name, name);

    fputs(runtime_source, out);
    fputs("\n/* ---- the description, frozen ---- */\n\n", out);

    emit_rules(&e);
    emit_passes(&e);
    emit_drivers(&e);

    /* The description's own text, so that a fault in a pass still reports
     * against the line of the `.phx` that caused it -- from a program the
     * `.phx` is no longer beside. */
    fputs("\nstatic char phx_description[] =\n  ", out);
    for (size_t i = 0; i < g->src.size; i += 60) {
        size_t n = g->src.size - i < 60 ? g->src.size - i : 60;
        emit_text(&e, g->src.text + i, n);
        fputs("\n  ", out);
    }
    fputs(";\n", out);

    fputs("\nstatic Unit phx_units[] = {\n", out);
    for (int i = 0; i < g->map.n; i++) {
        fputs("  {", out);
        emit_string(&e, g->map.units[i].path);
        fprintf(out, ",%zu,%zu},\n", g->map.units[i].start, g->map.units[i].size);
    }
    fputs("};\n", out);

    fprintf(out, "\nstatic char *phx_reserved[] = {");
    for (int i = 0; i < g->nreserved; i++) {
        emit_string(&e, g->reserved[i]);
        fputc(',', out);
    }
    fputs("};\n", out);

    fprintf(out,
        "\nstatic SourceMap phx_map = { phx_units, %d, %d };\n"
        "\nstatic Grammar phx_grammar = {\n"
        "  NULL,\n"
        "  { \"%s\", phx_description, sizeof phx_description - 1, &phx_map },\n"
        "  { phx_units, %d, %d },\n"
        "  NULL, 0, 0,\n"
        "  phx_rules, %d, %d,\n"
        "  %d, %d,\n"
        "  phx_reserved, %d,\n"
        "  phx_passes, %d, %d,\n"
        "  phx_drivers, %d, %d,\n"
        "  false\n"
        "};\n",
        g->map.n, g->map.n,
        g->map.n ? g->map.units[0].path : "",
        g->map.n, g->map.n,
        g->nrules, g->nrules,
        g->start, g->ignorecase,
        g->nreserved,
        g->npasses, g->npasses,
        g->ndrivers, g->ndrivers);

    fprintf(out, "%s", "\n"
        "/* ------------------------------------------------------------------ */\n"
        "\n"
        "int main(int argc, char **argv)\n"
        "{\n"
        "    const char *path = NULL, *want = NULL;\n"
        "\n"
        "    for (int i = 1; i < argc; i++) {\n"
        "        if (strcmp(argv[i], \"--driver\") == 0 && i + 1 < argc) {\n"
        "            want = argv[++i];\n"
        "            continue;\n"
        "        }\n"
        "        if (strcmp(argv[i], \"--drivers\") == 0) {\n"
        "            for (int k = 0; k < phx_grammar.ndrivers; k++)\n"
        "                printf(\"%s\\n\", phx_grammar.drivers[k].name);\n"
        "            return 0;\n"
        "        }\n"
        "        if (argv[i][0] == '-' && argv[i][1]) {\n"
        "            fprintf(stderr, \"%s: unknown option %s\\n\", argv[0], argv[i]);\n"
        "            return 2;\n"
        "        }\n"
        "        path = argv[i];\n"
        "    }\n"
        "\n"
        "    if (!path) {\n"
        "        fprintf(stderr, \"usage: %s [--driver NAME] <file>\\n\", argv[0]);\n"
        "        return 2;\n"
        "    }\n"
        "\n"
        "    Arena *a = arena_new();\n"
        "    phx_grammar.arena = a;\n"
        "\n"
        "    Source src;\n"
        "    if (!source_read(a, path, &src)) return 1;\n"
        "\n"
        "    Tokens toks;\n"
        "    if (!lex_run(a, &phx_grammar, &src, &toks)) return 1;\n"
        "\n"
        "    Value *tree = parse_run(a, &phx_grammar, &src, &toks);\n"
        "    if (!tree) return 1;\n"
        "\n"
        "    const Driver *driver = phx_grammar.ndrivers ? &phx_grammar.drivers[0] : NULL;\n"
        "    if (want) {\n"
        "        driver = driver_find(&phx_grammar, want);\n"
        "        if (!driver) {\n"
        "            fprintf(stderr, \"%s: there is no driver called '%s'\\n\",\n"
        "                    argv[0], want);\n"
        "            return 2;\n"
        "        }\n"
        "    }\n"
        "    if (!driver) { tree_dump(stdout, tree); return 0; }\n"
        "\n"
        "    for (int i = 0; i < driver->npasses; i++) {\n"
        "        const Pass *pass = pass_find(&phx_grammar, driver->passes[i]);\n"
        "        if (!pass_run(a, &phx_grammar, &src, pass, tree)) return 1;\n"
        "    }\n"
        "    if (!driver->answer) return 0;\n"
        "\n"
        "    Value *answer = pass_attr(tree, driver->answer);\n"
        "    if (!answer) {\n"
        "        fprintf(stderr, \"%s: nothing left a '%s' on the root\\n\",\n"
        "                argv[0], driver->answer);\n"
        "        return 1;\n"
        "    }\n"
        "\n"
        "    char  *text;\n"
        "    size_t len;\n"
        "    if (value_format(a, answer, &text, &len)) {\n"
        "        fwrite(text, 1, len, stdout);\n"
        "        if (len == 0 || text[len - 1] != '\\n') fputc('\\n', stdout);\n"
        "    } else {\n"
        "        tree_dump(stdout, answer);\n"
        "    }\n"
        "    return 0;\n"
        "}\n");

    return true;
}
