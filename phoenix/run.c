/* run.c -- running a pass over a tree.
 *
 * ---------------------------------------------------------------------------
 * The model, stated plainly, because it is the thing that can be wrong
 *
 * **One walk, post-order, two phases at each node.**
 *
 *   1. entering  -- `down` clauses run, and what they define is visible to
 *                   everything below this node and to nothing else
 *   2. the children, left to right, each one walked whole
 *   3. leaving   -- everything else runs: synthesised attributes, threaded
 *                   updates, and the checks
 *
 * The sketch for this stage proposed demand-driven evaluation with
 * memoisation, the way JastAdd does it. That was dropped, and the reason is
 * worth keeping: **a threaded attribute needs a defined traversal order, and
 * demand-driven evaluation has none.** Once a walk exists for `thread` to be
 * threaded along, computing everything else during that same walk is simpler
 * than being lazy, has no scheduling problem to solve, and cannot have a cycle
 * because a node's attributes are computed strictly after its children's.
 *
 * What it costs: an attribute is computed whether or not anything reads it,
 * and an attribute cannot refer *forward* to a node the walk has not reached.
 * The first is nothing at these sizes. The second is what several passes and a
 * `%driver` are for -- collect in one pass, use in the next, which is how a
 * hand-written compiler handles forward references anyway.
 *
 * ---------------------------------------------------------------------------
 * What `$name` means, in order
 *
 *   1. something the pattern bound
 *   2. a field of the node being visited
 *   3. an attribute of it, from an earlier pass or an earlier clause
 *   4. a threaded attribute's value here
 *   5. an inherited attribute in scope
 *
 * The order matters only when a name is used twice, and the innermost thing
 * wins, which is what every language does.
 */
#include "phx.h"

#include <string.h>

/* What a pass has worked out about one node. */
typedef struct Attr Attr;
struct Attr {
    const char *name;
    Value      *value;
    Attr       *next;
};

/* An inherited attribute, live for the subtree below the node that defined it. */
typedef struct Scope Scope;
struct Scope {
    const char *name;
    Value      *value;
    Scope      *outer;
};

typedef struct {
    const char *name;
    Value      *value;
} Threaded;

typedef struct {
    Arena         *a;
    const Grammar *g;
    const Source  *src;      /* the file being compiled, for messages */
    const Pass    *pass;

    Threaded      *threads;
    Scope         *scope;

    /* the node being visited, and what its pattern bound */
    Value         *node;
    const char   **bound;
    Value        **bounds;
    int            nbound;
} Run;

/* ------------------------------------------------------------------ */
/* Attributes on a node */

static Value *attr_get(const Value *node, const char *name)
{
    for (Attr *at = node->attrs; at; at = at->next)
        if (strcmp(at->name, name) == 0) return at->value;
    return NULL;
}

static void attr_set(Run *r, Value *node, const char *name, Value *value)
{
    for (Attr *at = node->attrs; at; at = at->next)
        if (strcmp(at->name, name) == 0) { at->value = value; return; }

    Attr *at = arena_alloc(r->a, sizeof *at);
    at->name  = name;
    at->value = value;
    at->next  = node->attrs;
    node->attrs = at;
}

/* ------------------------------------------------------------------ */
/* Matching a pattern */

static bool match_pattern(Run *r, const Pattern *p, Value *v);

static bool bind_name(Run *r, const char *name, Value *v)
{
    const char **names  = arena_alloc(r->a, (size_t)(r->nbound + 1) * sizeof *names);
    Value      **values = arena_alloc(r->a, (size_t)(r->nbound + 1) * sizeof *values);

    memcpy(names,  r->bound,  (size_t)r->nbound * sizeof *names);
    memcpy(values, r->bounds, (size_t)r->nbound * sizeof *values);

    names[r->nbound]  = name;
    values[r->nbound] = v;

    r->bound  = names;
    r->bounds = values;
    r->nbound++;
    return true;
}

static Value *field_of(const Value *node, const char *name)
{
    if (node->kind != V_NODE || !node->fields) return NULL;
    for (int i = 0; i < node->n; i++)
        if (node->fields[i] && strcmp(node->fields[i], name) == 0)
            return node->items[i];
    return NULL;
}

static bool match_pattern(Run *r, const Pattern *p, Value *v)
{
    switch (p->kind) {
    case P_ANY:
        return true;

    case P_BIND:
        return bind_name(r, p->name, v);

    case P_TEXT:
        return v->kind == V_TEXT && v->len == (size_t)p->len
            && memcmp(v->text, p->name, v->len) == 0;

    case P_INT:
        return v->kind == V_INT && v->ival == p->ival;

    case P_BOOL:
        return v->kind == V_BOOL && (v->ival != 0) == (p->ival != 0);

    case P_NIL:
        return v->kind == V_NIL;

    case P_TYPE: {
        if (v->kind != V_NODE || !v->type || strcmp(v->type, p->name) != 0)
            return false;

        /* A field the pattern does not mention is not looked at. */
        for (int i = 0; i < p->nkids; i++) {
            Value *got = field_of(v, p->fields[i]);
            if (!got) return false;
            if (!match_pattern(r, p->kids[i], got)) return false;
        }
        return true;
    }
    }
    return false;
}

/* ------------------------------------------------------------------ */
/* What a name means here */

static Value *run_ref(Eval *e, const Expr *x)
{
    Run *r = e->data;

    if (x->kind == X_ACC) {
        diag_error(&r->g->src, x->pos,
                   "$$ belongs in a production's action, not in a pass");
        return NULL;
    }

    if (x->kind == X_DOT) {
        Value *of = eval_expr(e, x->kids[0]);
        if (!of) return NULL;
        if (value_failed(of)) return of;

        /* An attribute of a **list** is that attribute of each element. It
         * is what `join($body.out)` has to mean, and writing it out by hand
         * would need a map, a lambda and a reason. */
        if (of->kind == V_LIST) {
            Value **items = arena_alloc(r->a, (size_t)(of->n ? of->n : 1)
                                               * sizeof *items);
            for (int i = 0; i < of->n; i++) {
                if (of->items[i]->kind != V_NODE) {
                    diag_error(&r->g->src, x->pos,
                               "'.%s' over a list wants nodes, and element %d is %s",
                               x->name, i + 1, value_kind_name(of->items[i]));
                    return NULL;
                }
                items[i] = field_of(of->items[i], x->name);
                if (!items[i]) items[i] = attr_get(of->items[i], x->name);
                if (!items[i]) {
                    if (diag_failed()) return value_error(r->a);
                    diag_error(&r->g->src, x->pos,
                               "'%s' has no field or attribute '%s' in pass '%s'",
                               of->items[i]->type, x->name, r->pass->name);
                    return NULL;
                }
            }
            Value *list = arena_alloc(r->a, sizeof *list);
            list->kind  = V_LIST;
            list->items = items;
            list->n     = of->n;
            return list;
        }

        if (of->kind != V_NODE) {
            diag_error(&r->g->src, x->pos,
                       "'.%s' reads an attribute, and this is %s",
                       x->name, value_kind_name(of));
            return NULL;
        }
        /* A field of it, then what a pass worked out about it -- the same
         * order `$name` uses on the node being visited, so there is one rule
         * to know rather than two. */
        Value *got = field_of(of, x->name);
        if (!got) got = attr_get(of, x->name);

        if (!got) {
            /* Once something has gone wrong, a missing attribute is very
             * likely a consequence of it rather than a mistake of its own. */
            if (diag_failed()) return value_error(r->a);
            diag_error(&r->g->src, x->pos,
                       "'%s' has no field or attribute '%s' in pass '%s'",
                       of->type, x->name, r->pass->name);
            return NULL;
        }
        return got;
    }

    if (!x->name) {
        diag_error(&r->g->src, x->pos,
                   "$%d numbers a production's factors, and a pass matches "
                   "nodes -- name the field instead", x->index);
        return NULL;
    }

    for (int i = r->nbound - 1; i >= 0; i--)               /* 1. bound */
        if (strcmp(r->bound[i], x->name) == 0) return r->bounds[i];

    Value *field = field_of(r->node, x->name);             /* 2. a field */
    if (field) return field;

    /* 3. something a pass worked out about *this* node -- an earlier pass in
     * the driver, or an earlier clause of this one. Without this, reading
     * what a previous pass left required going through a child, which is a
     * strange thing to have to do to read your own attribute. */
    Value *own = attr_get(r->node, x->name);
    if (own) return own;

    for (int i = 0; i < r->pass->nthreads; i++)            /* 4. threaded */
        if (strcmp(r->threads[i].name, x->name) == 0) {
            if (!r->threads[i].value) {
                diag_error(&r->g->src, x->pos,
                           "'%s' is threaded but has no value yet -- "
                           "give it one on its `thread` line", x->name);
                return NULL;
            }
            return r->threads[i].value;
        }

    for (Scope *s = r->scope; s; s = s->outer)             /* 5. inherited */
        if (strcmp(s->name, x->name) == 0) return s->value;

    diag_error(&r->g->src, x->pos,
               "nothing here is called '%s' -- not a binding, a field of %s, "
               "an attribute of it, a threaded attribute, or one handed down",
               x->name, r->node->type ? r->node->type : "this node");
    return NULL;
}

/* ------------------------------------------------------------------ */

static void walk(Run *r, Value *v);

static const PassRule *find_rule(Run *r, Value *v)
{
    for (int i = 0; i < r->pass->nrules; i++) {
        r->nbound = 0;                       /* a failed match binds nothing */
        if (match_pattern(r, r->pass->rules[i].pattern, v))
            return &r->pass->rules[i];
    }
    r->nbound = 0;
    return NULL;
}

/* A check is a **guard**, not a clause that happens to print.
 *
 * If one fires, this node's attributes are not computed -- they are set to a
 * failure instead. `Binary(op: "/") ! $right.val = 0 : "division by zero"`
 * would otherwise report the pass's own division by zero as well as its own
 * message, and `Variable`'s undefined name would leave a nil for the addition
 * above it to complain about separately. One mistake, one message.
 *
 * Which is why checks run first at a node, whatever order they were written in.
 */
static bool checks_fired(Run *r, Value *v, const PassRule *rule, Eval *e)
{
    bool fired = false;

    for (int i = 0; i < rule->nclauses; i++) {
        const Clause *c = &rule->clauses[i];
        if (c->kind != C_ERROR) continue;

        e->pos = v->pos;

        Value *cond = eval_expr(e, c->when);
        if (!cond)                { fired = true; continue; }
        if (value_failed(cond))   { fired = true; continue; }

        if (cond->kind != V_BOOL) {
            diag_error(&r->g->src, c->pos,
                       "a check wants a boolean, and this is %s",
                       value_kind_name(cond));
            fired = true;
            continue;
        }
        if (!cond->ival) continue;

        Value *message = eval_expr(e, c->value);
        if (!message || value_failed(message)) { fired = true; continue; }

        if (message->kind != V_TEXT) {
            diag_error(&r->g->src, c->pos,
                       "a check reports text, and this is %s",
                       value_kind_name(message));
            fired = true;
            continue;
        }
        /* Reported against the file being compiled, at the node -- which is
         * the whole reason a node carries a position. */
        diag_error(r->src, v->pos, "%.*s", (int)message->len, message->text);
        fired = true;
    }
    return fired;
}

static void run_clauses(Run *r, Value *v, const PassRule *rule, bool entering)
{
    Eval e = { .a = r->a, .g = r->g, .ref = run_ref, .data = r };

    bool blocked = false;
    if (!entering) blocked = checks_fired(r, v, rule, &e);

    for (int i = 0; i < rule->nclauses; i++) {
        const Clause *c = &rule->clauses[i];

        if ((c->kind == C_DOWN) != entering) continue;

        if (c->kind == C_ERROR) continue;      /* done, above */

        e.pos = v->pos;

        Value *got = blocked ? value_error(r->a) : eval_expr(&e, c->value);

        /* A clause that could not be worked out leaves a failure in the
         * attribute rather than leaving it absent. Absent would make every
         * node above report that this one is missing something, which is the
         * same mistake said four more times. */
        if (!got) got = value_error(r->a);

        switch (c->kind) {
        case C_SYNTH:
            attr_set(r, v, c->attr, got);
            break;

        case C_THREAD:
            for (int k = 0; k < r->pass->nthreads; k++)
                if (strcmp(r->threads[k].name, c->attr) == 0)
                    r->threads[k].value = got;
            break;

        case C_DOWN: {
            Scope *s = arena_alloc(r->a, sizeof *s);
            s->name  = c->attr;
            s->value = got;
            s->outer = r->scope;
            r->scope = s;
            break;
        }
        case C_ERROR:
            break;
        }
    }
}

static void walk(Run *r, Value *v)
{
    if (v->kind == V_LIST) {
        for (int i = 0; i < v->n; i++) walk(r, v->items[i]);
        return;
    }
    if (v->kind != V_NODE) return;

    /* The state belonging to the node above is put back on the way out, so
     * that a sibling sees what its parent set and not what its sibling did. */
    Value       *outer_node   = r->node;
    const char **outer_bound  = r->bound;
    Value      **outer_bounds = r->bounds;
    int          outer_nbound = r->nbound;
    Scope       *outer_scope  = r->scope;

    const PassRule *rule = find_rule(r, v);
    r->node = v;

    if (rule) run_clauses(r, v, rule, true);      /* entering: `down` */

    /* The bindings belong to this node; its children rebind for themselves. */
    const char **mine   = r->bound;
    Value      **minev  = r->bounds;
    int          minen  = r->nbound;

    for (int i = 0; i < v->n; i++) walk(r, v->items[i]);

    r->node   = v;
    r->bound  = mine;
    r->bounds = minev;
    r->nbound = minen;

    if (rule) run_clauses(r, v, rule, false);     /* leaving: everything else */

    r->node   = outer_node;
    r->bound  = outer_bound;
    r->bounds = outer_bounds;
    r->nbound = outer_nbound;
    r->scope  = outer_scope;
}

/* ------------------------------------------------------------------ */

const Pass *pass_find(const Grammar *g, const char *name)
{
    for (int i = 0; i < g->npasses; i++)
        if (strcmp(g->passes[i].name, name) == 0) return &g->passes[i];
    return NULL;
}

const Driver *driver_find(const Grammar *g, const char *name)
{
    for (int i = 0; i < g->ndrivers; i++)
        if (strcmp(g->drivers[i].name, name) == 0) return &g->drivers[i];
    return NULL;
}

const Driver *driver_default(const Grammar *g)
{
    if (!g->ndrivers) return NULL;

    /* An import is read before the file that imports it, so "the first
     * declared" would hand the default to the imported description -- and
     * `pascal-outline.phx` would run `pascal.phx`'s checker instead of its own
     * outline. The file named on the command line is the first unit. */
    if (g->map.n) {
        size_t from = g->map.units[0].start;
        size_t to   = from + g->map.units[0].size;

        for (int i = 0; i < g->ndrivers; i++)
            if (g->drivers[i].pos >= from && g->drivers[i].pos < to)
                return &g->drivers[i];
    }
    return &g->drivers[0];
}

bool pass_run(Arena *a, const Grammar *g, const Source *src,
              const Pass *pass, Value *root)
{
    Run r = { .a = a, .g = g, .src = src, .pass = pass };

    r.threads = arena_alloc(a, (size_t)(pass->nthreads ? pass->nthreads : 1)
                                * sizeof *r.threads);

    Eval e = { .a = a, .g = g, .ref = run_ref, .data = &r };
    r.node = root;

    for (int i = 0; i < pass->nthreads; i++) {
        r.threads[i].name  = pass->threads[i];
        r.threads[i].value = NULL;

        if (pass->initial[i]) {
            r.threads[i].value = eval_expr(&e, pass->initial[i]);
            if (!r.threads[i].value) return false;
        }
    }

    walk(&r, root);
    return !diag_failed();
}

Value *pass_attr(const Value *node, const char *name)
{
    return attr_get(node, name);
}
