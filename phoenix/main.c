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

#include <unistd.h>

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
    "  --run PASS   run a %pass over the tree and print what it worked out\n"
    "  --show ATTR  which attribute --run prints from the root (default: out)\n"
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
    const char *show_attr    = "out";
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

    if (run_pass) {
        const Pass *pass = pass_find(g, run_pass);
        if (!pass) {
            fprintf(stderr, "phx: there is no pass called '%s'\n", run_pass);
            arena_free(a);
            return 2;
        }
        if (!pass_run(a, g, &src, pass, tree)) { arena_free(a); return 1; }

        Value *answer = pass_attr(tree, show_attr);
        if (!answer) {
            fprintf(stderr, "phx: pass '%s' left no '%s' on the root\n",
                    run_pass, show_attr);
            arena_free(a);
            return 1;
        }

        if (!quiet) {
            char  *text;
            size_t len;
            if (value_format(a, answer, &text, &len)) {
                fwrite(text, 1, len, stdout);
                if (len == 0 || text[len - 1] != '\n') fputc('\n', stdout);
            } else {
                tree_dump(stdout, answer);
            }
        }
        arena_free(a);
        return 0;
    }

    if (!quiet) tree_dump(stdout, tree);

    arena_free(a);
    return 0;
}
