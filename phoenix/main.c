/* main.c -- the driver.
 *
 * Stage 0's whole job:
 *
 *     phx grammar.phx                 read the grammar and say what is in it
 *     phx grammar.phx source          parse a file and print its tree
 *     phx --tokens grammar.phx source stop after the scanner
 */
#include "phx.h"
#include "reader.h"


#include <stdlib.h>
#include <string.h>

/* ------------------------------------------------------------------ */
/* Where the shared modules live
 *
 * `%import "lexical.phx"` is looked for beside the description that named it
 * and then here, so that a module every language wants is found without every
 * description saying where it is.
 *
 * `$PHX_LIB` first, for anyone who has put them somewhere else; otherwise
 * `lib/` beside the running executable, so that a built tree works from any
 * directory without being installed.
 */
const char *phx_library_path(Arena *a)
{
    const char *set = getenv("PHX_LIB");
    if (set && *set) {
        size_t n = strlen(set);
        char  *p = arena_alloc(a, n + 2);
        memcpy(p, set, n);
        if (n && p[n - 1] != '/') p[n++] = '/';
        p[n] = '\0';
        return p;
    }

    /* argv[0]'s directory, then `../lib/` -- bin/phx puts us one below. */
    extern const char *phx_argv0;
    const char *slash = phx_argv0 ? strrchr(phx_argv0, '/') : NULL;

    if (!slash) return "lib/";

    size_t dir = (size_t)(slash - phx_argv0) + 1;
    char  *p   = arena_alloc(a, dir + 8);
    memcpy(p, phx_argv0, dir);
    memcpy(p + dir, "../lib/", 8);
    return p;
}

const char *phx_argv0;

static const char usage[] =
    "phx -- a compiler-compiler\n"
    "\n"
    "usage: phx [options] <grammar.phx> [source]\n"
    "\n"
    "  With no source, reads the grammar, checks it and prints it back.\n"
    "  With a source, scans and parses it and prints the tree.\n"
    "\n"
    "options:\n"
    "  --tokens     print the token stream and stop\n"
    "  --nodes      print the node types the grammar builds, and stop\n"
    "  --imports    list the files the description was assembled from\n"
    "  -o FILE.c      write this description out as a C program that is its\n"
    "                 compiler, and stop\n"
    "  --tree         print the tree and stop, whatever drivers there are\n"
    "  --stats        report how much work reading the source took\n"
    "  --raw          write the answer exactly, adding no trailing newline --\n"
    "                 which a description emitting a binary format needs\n"
    "  --driver NAME  which %driver to run (default: the first declared)\n"
    "  --drivers      list the drivers this description declares\n"
    "  --run PASS     run one %pass on its own, for looking at it\n"
    "  --show ATTR    which attribute to print from the root, overriding\n"
    "                 whatever the driver answers with\n"
    "  --grammar    print the grammar as it was understood\n"
    "  --quiet      say nothing on success; the exit status is the answer\n"
    "  --help       this\n";

int main(int argc, char **argv)
{
    phx_argv0 = argv[0];

    const char *grammar_path = NULL;
    const char *source_path  = NULL;
    bool        want_tokens  = false;
    bool        want_grammar = false;
    bool        want_nodes   = false;
    bool        want_imports = false;
    const char *run_pass     = NULL;
    const char *show_attr    = NULL;
    const char *driver_name  = NULL;
    bool        want_drivers = false;
    bool        want_tree    = false;
    bool        want_stats   = false;
    bool        want_raw     = false;
    const char *compile_to   = NULL;
    bool        quiet        = false;

    for (int i = 1; i < argc; i++) {
        const char *arg = argv[i];

        if (strcmp(arg, "--help") == 0 || strcmp(arg, "-h") == 0) {
            fputs(usage, stdout);
            return 0;
        }
        if (strcmp(arg, "--tokens")  == 0) { want_tokens  = true; continue; }
        if (strcmp(arg, "--nodes")   == 0) { want_nodes   = true; continue; }
        if (strcmp(arg, "--imports") == 0) { want_imports = true; continue; }
        if (strcmp(arg, "--drivers") == 0) { want_drivers = true; continue; }
        if (strcmp(arg, "--tree")    == 0) { want_tree    = true; continue; }
        if (strcmp(arg, "--stats")   == 0) { want_stats   = true; continue; }
        if (strcmp(arg, "--raw")     == 0) { want_raw     = true; continue; }

        if (strcmp(arg, "-o") == 0) {
            if (i + 1 >= argc) {
                fprintf(stderr, "phx: -o wants a file to write\n");
                return 2;
            }
            compile_to = argv[++i];
            continue;
        }

        if (strcmp(arg, "--driver") == 0) {
            if (i + 1 >= argc) {
                fprintf(stderr, "phx: --driver wants a name\n");
                return 2;
            }
            driver_name = argv[++i];
            continue;
        }

        if (strcmp(arg, "--run") == 0) {
            if (i + 1 >= argc) {
                fprintf(stderr, "phx: --run wants the name of a pass\n");
                return 2;
            }
            run_pass = argv[++i];
            continue;
        }
        if (strcmp(arg, "--show") == 0) {
            if (i + 1 >= argc) {
                fprintf(stderr, "phx: --show wants the name of an attribute\n");
                return 2;
            }
            show_attr = argv[++i];
            continue;
        }
        if (strcmp(arg, "--grammar") == 0) { want_grammar = true; continue; }
        if (strcmp(arg, "--quiet")   == 0) { quiet        = true; continue; }

        if (arg[0] == '-' && arg[1]) {
            fprintf(stderr, "phx: unknown option %s\n", arg);
            return 2;
        }
        if      (!grammar_path) grammar_path = arg;
        else if (!source_path)  source_path  = arg;
        else {
            fprintf(stderr, "phx: too many files\n");
            return 2;
        }
    }

    if (!grammar_path) {
        fputs(usage, stderr);
        return 2;
    }

    Arena   *a = arena_new();
    Grammar *g = grammar_read(a, grammar_path);
    if (!g) { arena_free(a); return 1; }

    if (compile_to) {
        if (g->incomplete) {
            fprintf(stderr, "%s: this description has holes in it, so there is "
                            "no compiler to write\n", grammar_path);
            arena_free(a);
            return 1;
        }
        if (g->start < 0) {
            fprintf(stderr, "%s: there are no syntactic rules, so there is "
                            "nothing to compile\n", grammar_path);
            arena_free(a);
            return 1;
        }

        FILE *f = fopen(compile_to, "w");
        if (!f) {
            fprintf(stderr, "phx: cannot write %s\n", compile_to);
            arena_free(a);
            return 1;
        }
        bool ok = emit_compiler(g, compile_to, f);
        fclose(f);

        arena_free(a);
        return ok ? 0 : 1;
    }

    if (want_drivers) {
        for (int i = 0; i < g->ndrivers; i++) {
            const Driver *d = &g->drivers[i];
            const Driver *def = driver_default(g);
            printf("%-12s = ", d->name);
            for (int k = 0; k < d->npasses; k++)
                printf("%s%s", k ? ", " : "", d->passes[k]);
            if (d->answer) printf(" -> %s", d->answer);
            printf("%s\n", d == def ? "        (the default)" : "");
        }
        if (!g->ndrivers) fputs("phx: this description declares no drivers\n", stderr);
        arena_free(a);
        return diag_failed() ? 1 : 0;
    }

    if (want_imports) {
        for (int i = 0; i < g->map.n; i++) printf("%s\n", g->map.units[i].path);
        arena_free(a);
        return diag_failed() ? 1 : 0;
    }

    if (want_nodes) {
        if (!quiet) grammar_nodes(stdout, g);
        arena_free(a);
        return diag_failed() ? 1 : 0;
    }

    if (want_grammar || !source_path) {
        if (!quiet) grammar_dump(stdout, g);
        if (!source_path) {
            int status = diag_failed() ? 1 : 0;
            arena_free(a);
            return status;
        }
    }

    if (g->incomplete) {
        fprintf(stderr, "%s: this description has holes in it, so it cannot "
                        "parse %s\n", grammar_path, source_path);
        for (int i = 0; i < g->nrules; i++)
            if (g->rules[i].required && !g->rules[i].body)
                fprintf(stderr, "phx:   '%s' is required and never defined\n",
                        g->rules[i].name);
        fprintf(stderr, "phx: a module that requires a rule is imported by a "
                        "description that defines it\n");
        arena_free(a);
        return 1;
    }

    if (g->start < 0) {
        fprintf(stderr,
                "%s: there are no syntactic rules, so there is nothing to "
                "parse %s with\n", grammar_path, source_path);
        fprintf(stderr, "phx: add %%syntax before the rules that are matched "
                        "over tokens -- a description with only lexical rules "
                        "is a module to import, not one to use\n");
        arena_free(a);
        return 1;
    }

    Source src;
    if (!source_read(a, source_path, &src)) { arena_free(a); return 1; }

    Tokens toks;
    if (!lex_run(a, g, &src, &toks)) { arena_free(a); return 1; }

    if (want_tokens) {
        if (!quiet) tokens_dump(stdout, g, &src, &toks);
        arena_free(a);
        return 0;
    }

    Value *tree = parse_run(a, g, &src, &toks);
    if (!tree) { arena_free(a); return 1; }

    if (want_stats) {
        const Work *w = work_done();
        fprintf(stderr,
                "%zu bytes  %d tokens  %lld nodes  "
                "%lld scan-steps  %lld match-steps  depth %d  "
                "(%.1f match-steps per token)\n",
                src.size, toks.n, w->nodes, w->lex_steps, w->parse_steps, w->depth,
                toks.n ? (double)w->parse_steps / toks.n : 0.0);
    }

    /* What to run: one pass named on the command line, or a driver -- the one
     * named, or the first declared, or none at all, in which case the tree is
     * what there is to show. */
    if (want_tree) {
        if (!quiet) tree_dump(stdout, tree);
        arena_free(a);
        return 0;
    }

    const Driver *driver = NULL;

    if (!run_pass) {
        if (driver_name) {
            driver = driver_find(g, driver_name);
            if (!driver) {
                fprintf(stderr, "phx: there is no driver called '%s'\n",
                        driver_name);
                if (g->ndrivers) {
                    fputs("phx: this description has ", stderr);
                    for (int i = 0; i < g->ndrivers; i++)
                        fprintf(stderr, "%s%s", i ? ", " : "", g->drivers[i].name);
                    fputc('\n', stderr);
                }
                arena_free(a);
                return 2;
            }
        } else {
            driver = driver_default(g);
        }
    }

    const char *answer_attr = show_attr;

    if (run_pass) {
        const Pass *pass = pass_find(g, run_pass);
        if (!pass) {
            fprintf(stderr, "phx: there is no pass called '%s'\n", run_pass);
            arena_free(a);
            return 2;
        }
        if (!pass_run(a, g, &src, pass, tree)) { arena_free(a); return 1; }
        if (!answer_attr) answer_attr = "out";

    } else if (driver) {
        /* Each pass is a complete walk, in the order written, and the
         * attributes stay on the nodes between them -- which is what makes a
         * sequence worth having. A pass that reports stops the ones after it:
         * a later pass reading what a failed one left produces consequences of
         * the first mistake rather than new information. */
        for (int i = 0; i < driver->npasses; i++) {
            const Pass *pass = pass_find(g, driver->passes[i]);
            if (!pass_run(a, g, &src, pass, tree)) { arena_free(a); return 1; }
        }
        if (!answer_attr) answer_attr = driver->answer;

        if (!answer_attr) {          /* a validation run says nothing */
            arena_free(a);
            return 0;
        }
    } else {
        if (!quiet) tree_dump(stdout, tree);
        arena_free(a);
        return 0;
    }

    Value *answer = pass_attr(tree, answer_attr);
    if (!answer) {
        fprintf(stderr, "phx: nothing left a '%s' on the root\n", answer_attr);
        arena_free(a);
        return 1;
    }

    if (!quiet) {
        char  *text;
        size_t len;
        if (value_format(a, answer, &text, &len)) {
            fwrite(text, 1, len, stdout);
            /* A trailing newline is a kindness to a terminal and a corruption
             * of a binary file, so a description emitting one asks for --raw. */
            if (!want_raw && (len == 0 || text[len - 1] != '\n'))
                fputc('\n', stdout);
        } else {
            tree_dump(stdout, answer);
        }
    }

    arena_free(a);
    return 0;
}
