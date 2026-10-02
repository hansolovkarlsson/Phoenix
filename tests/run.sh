#!/bin/sh
# tests/run.sh -- what Phoenix is expected to do, and what it is expected to
# refuse. Run from the repository root, or by `make test`.

set -u

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
phx="$root/bin/phx"

# Everything this file runs, it runs under a limit: phx itself, every program
# phx or cc has just made, and each of the harnesses below it, which run their
# own programs the same way. A regression that makes one of them loop forever,
# or print forever, then fails the check that ran it, with `did not finish`
# in the reason, instead of hanging the suite, or taking it down with a shell
# out of memory. A program gets PHX_LIMIT seconds and a harness, which runs a
# directory of them, PHX_HARNESS_LIMIT. Both defaults are several times what
# the slowest one takes today. See tests/limit.sh and tests/limit.c.
. "$root/tests/limit.sh"

# Every stop, in any harness, is written here as well, and the last check
# before the summary fails if anything is. A check can be fooled by a stop:
# one that expects a failure and throws standard error away takes it for the
# failure it wanted, and an oracle whose two programs were both stopped sees
# two empty answers agree. The log is not fooled.
mkdir -p "$root/build"
PHX_LIMIT_LOG="$root/build/stopped.log"; rm -f "$PHX_LIMIT_LOG"
export PHX_LIMIT_LOG
# A harness that ran out says so in a FAIL line of its own, because what is
# shown of a failed harness below is mostly its FAIL lines. No harness exits
# 124 of itself, so here the number is enough.
harness() {
    "$limit" "${PHX_HARNESS_LIMIT:-600}" "$@"; _st=$?
    [ "$_st" = 124 ] && printf '  FAIL  %s did not finish\n' "${1#"$root"/}"
    return "$_st"
}

pass=0
fail=0
skipped=0
# How many of the three optional oracles, fpc, Solveig and z80asm, are
# missing. The README quotes what a run with none of them does, and that
# number can only be judged by such a run: see the foot of this file.
absent=0

report() {
    if [ "$1" = pass ]; then
        pass=$((pass + 1))
        printf '  ok    %s\n' "$2"
    else
        fail=$((fail + 1))
        printf '  FAIL  %s\n' "$2"
        [ -n "${3:-}" ] && printf '        %s\n' "$3"
    fi
}

# skip <how many> <why> -- a guard that could not run its checks. The count is
# how many *checks* are behind the guard rather than how many lines are
# printed, because one guard can hold several: a machine without Solveig loses
# three and is told so once.
skip() {
    skipped=$((skipped + $1))
    printf '  --    %s\n' "$2"
}

# accepts <what> <args...>
accepts() {
    what=$1; shift
    if out=$(bounded "$phx" --quiet "$@" 2>&1); then
        report pass "$what"
    else
        report fail "$what" "$(printf '%s' "$out" | head -2 | tr '\n' ' ')"
    fi
}

# refuses <what> <expected text> <args...>
refuses() {
    what=$1; _want=$2; shift 2
    if out=$(bounded "$phx" --quiet "$@" 2>&1); then
        report fail "$what" "it was accepted"
    elif printf '%s' "$out" | grep -qF -- "$_want"; then
        report pass "$what"
    else
        report fail "$what" "wanted '$_want', got: $(printf '%s' "$out" | head -1)"
    fi
}

# prints <what> <expected> <args...> -- what phx writes, exactly.
prints() {
    what=$1; _want=$2; shift 2
    got=$(bounded "$phx" "$@" 2>&1)
    if [ "$got" = "$_want" ]; then
        report pass "$what"
    else
        report fail "$what" "wanted '$_want', got '$got'"
    fi
}

# warns <what> <expected text> <args...>
warns() {
    what=$1; _want=$2; shift 2
    out=$(bounded "$phx" --quiet "$@" 2>&1)
    if printf '%s' "$out" | grep -qF -- "$_want"; then
        report pass "$what"
    else
        report fail "$what" "no warning matching '$_want'"
    fi
}

# The instrument first, because everything below is run through it. A limit
# that swallowed exit statuses would pass every refusal, and one that never
# fired would bring back the hang it is here to end.
echo "the time limit"
"$limit" 5 sh -c 'exit 3' 2>/dev/null
if [ $? = 3 ]; then
    report pass "a program that finishes keeps its exit status"
else
    report fail "a program that finishes keeps its exit status"
fi
out=$(PHX_LIMIT_LOG= "$limit" 1 sh -c 'while :; do :; done' 2>&1)
if [ $? = 124 ] && printf '%s' "$out" | grep -q 'did not finish in 1 s'; then
    report pass "a program that never finishes is stopped, and says so"
else
    report fail "a program that never finishes is stopped, and says so" "got: $out"
fi
# The version of the same regression that is likelier, since most programs
# here print: a loop around the print. Time alone does not catch it, because
# `$(...)` runs the shell out of memory first.
out=$(PHX_LIMIT_LOG= "$limit" 20 yes 2>&1 >/dev/null)
if [ $? = 124 ] && printf '%s' "$out" | grep -q 'did not finish, and was stopped after writing'; then
    report pass "a program that never stops printing is stopped, and says so"
else
    report fail "a program that never stops printing is stopped, and says so" "got: $out"
fi

echo "grammars it should accept"
accepts "calc.phx"                  "$root/languages/calc/calc-c.phx"
accepts "an empty production"       "$root/tests/grammars/empty-production.phx"

echo "grammars it should refuse"
refuses "left recursion"    "left-recursive"   "$root/tests/grammars/left-recursion.phx"
refuses "an unknown rule"   "not a rule"       "$root/tests/grammars/unknown-rule.phx"
refuses "a range over tokens" "asks about characters" "$root/tests/grammars/range-in-syntax.phx"
refuses "no syntactic half, asked to parse" "no syntactic rules" \
        "$root/tests/grammars/no-syntax.phx" "$root/languages/calc/tests/one.calc"
accepts "no syntactic half, on its own" "$root/tests/grammars/no-syntax.phx"
refuses "a literal nothing spells" "no token rule spells" "$root/tests/grammars/unspellable.phx"
# Three mistakes that are decidable from the description alone, each of which
# was made more than once while writing languages/pascal. They are all about
# *when* a clause runs.
warns   "an attribute with a field's name" "is already a field of" \
        "$root/tests/grammars/attribute-shadows-field.phx"
refuses "a field of a threaded attribute's name" "does not pass through here" \
        "$root/tests/grammars/thread-shadowed.phx"
refuses "a thread declared below the rules that update it" \
        "declared a thread further down this pass" \
        "$root/tests/grammars/thread-declared-late.phx"
warns   "a field of an inherited attribute's name" "cannot read" \
        "$root/tests/grammars/down-shadowed.phx"
refuses "an inherited clause reading its own rule's work" \
        "an inherited clause runs on the way in" \
        "$root/tests/grammars/down-reads-own.phx"
refuses "a check reading the attributes it guards" \
        "a check runs before the attributes it guards" \
        "$root/tests/grammars/check-reads-own.phx"

refuses "a clause nothing can reach" "can never match" \
        "$root/tests/grammars/unreachable-clause.phx"
refuses "a fold with nothing to fold onto" "nothing to fold onto" \
        "$root/tests/grammars/fold-in-action.phx"

# A failed check is reported once. `join` has always passed a failure through;
# `sizes`, `each` and `bytes` over a list complained about it instead, so a
# correct diagnosis about the user's program was followed by one naming a line
# of the description. So did `and` and `or` with a failure on the right, until
# 2026-09-26, found by a cast in C refused and then asked about.
if out=$(bounded "$phx" --quiet "$root/tests/grammars/one-complaint.phx" \
            "$root/tests/sources/has-a-zero.txt" 2>&1); then
    report fail "a failed check is reported once" "it was accepted"
elif [ "$(printf '%s' "$out" | grep -c 'error:')" = 1 ]; then
    report pass "a failed check is reported once"
else
    report fail "a failed check is reported once" \
                "$(printf '%s' "$out" | grep -c 'error:') complaints"
fi

echo "grammars it should warn about"
warns "alternatives in the wrong order" "will always win" "$root/tests/grammars/order.phx"
warns "a fragment not declared one"     "%fragment"       "$root/tests/grammars/fragment-forgotten.phx"

# Scratch lives **inside this repository**, not in /var and never beside a
# source file somewhere else: a test that writes has to write here.
tmp0="$root/build/suite"; rm -rf "$tmp0"; mkdir -p "$tmp0"
trap 'rm -rf "$tmp0" "${tmp:-}"' EXIT

echo "imports"
accepts "the shared lexical module" "$root/lib/lexical.phx"
accepts "the shared expression module" "$root/lib/expression.phx"
accepts "the expression module, hole filled" "$root/tests/grammars/expression-only.phx"
refuses "a module used with its hole open" "holes in it" \
        "$root/lib/expression.phx" "$root/tests/sources/an-expression.txt"

# Precedence and associativity come from the module, and nothing that imports
# it restates them. This is the whole reason it exists, so it is checked
# exactly rather than approximately.
shown=$(bounded "$phx" --run show --show show \
        "$root/tests/grammars/expression-only.phx" \
        "$root/tests/sources/an-expression.txt" 2>/dev/null)
if [ "$shown" = "(((a + (2 * -b)) < 10) and not c)" ]; then
    report pass "the module's precedence, rendered back"
else
    report fail "the module's precedence, rendered back" "got: $shown"
fi

# calc's own grammar defines neither boolean operators nor unary minus; all of
# it arrives with the module, and calc only answers for the nodes.
if bounded "$phx" --run emit-c "$root/languages/calc/calc-c.phx" "$root/languages/calc/programs/logic.calc" \
        > "$tmp0/logic.c" 2>/dev/null \
   && cc -Wall -Werror -o "$tmp0/logic" "$tmp0/logic.c" 2>/dev/null; then
    got=$(bounded "$tmp0/logic")
    if [ "$got" = "21" ]; then
        report pass "operators the language never defined"
    else
        report fail "operators the language never defined" "got '$got', wanted 21"
    fi
else
    report fail "operators the language never defined" "it did not compile"
fi
accepts "a description in three files" "$root/languages/calc/calc-c.phx"
accepts "modules that import each other" "$root/tests/grammars/circular-a.phx"
refuses "a rule defined in two files" "already defined" \
        "$root/tests/grammars/duplicate-rule.phx"
refuses "an import that is not there" "cannot read" \
        "$root/tests/grammars/missing-import.phx"

# A file named twice is read once, so the joined text holds one copy.
# calc-c imports calc, which imports lexical and expression: four, each once.
listed=$(bounded "$phx" --imports "$root/languages/calc/calc-c.phx" 2>/dev/null)
seen=$(printf '%s\n' "$listed" | wc -l | tr -d ' ')
uniq=$(printf '%s\n' "$listed" | sort -u | wc -l | tr -d ' ')
if [ "$seen" = "4" ] && [ "$uniq" = "4" ]; then
    report pass "each file appears once"
else
    report fail "each file appears once" "listed $seen, distinct $uniq, wanted 4 and 4"
fi

# A message about an imported file has to name *that* file and its own line
# numbers, not a position in a buffer nobody wrote.
out=$(bounded "$phx" --quiet "$root/tests/grammars/duplicate-rule.phx" 2>&1)
if printf '%s' "$out" | grep -q "lexical.phx:"; then
    report pass "a diagnostic names the file it came from"
else
    report fail "a diagnostic names the file it came from" "$(printf '%s' "$out" | head -1)"
fi

echo "actions"
accepts "actions on calc.phx"   "$root/languages/calc/calc-c.phx"
accepts "a spread into a list"  "$root/tests/grammars/spread.phx"
refuses "a \$n past the last factor" "but this alternative" \
        "$root/tests/grammars/ref-out-of-range.phx"
refuses "a label nothing carries"    "is named" \
        "$root/tests/grammars/unknown-label.phx"
warns   "one node type, two shapes"  "elsewhere with" \
        "$root/tests/grammars/inconsistent-node.phx"

# The vocabulary a pass will be written against.
nodes=$(bounded "$phx" --nodes "$root/languages/calc/calc-c.phx" 2>/dev/null)
if printf '%s' "$nodes" | grep -q "^Binary(op, left, right)$"; then
    report pass "--nodes lists the vocabulary"
else
    report fail "--nodes lists the vocabulary" "got: $(printf '%s' "$nodes" | tr '\n' ' ')"
fi

echo "sources"
accepts "sum.calc"        "$root/languages/calc/calc-c.phx" "$root/languages/calc/programs/sum.calc"
accepts "one.calc"        "$root/languages/calc/calc-c.phx" "$root/languages/calc/tests/one.calc"
accepts "an empty tail"   "$root/tests/grammars/empty-production.phx" "$root/tests/sources/list.txt"
accepts "a spread over a file" "$root/tests/grammars/spread.phx" "$root/tests/sources/list.txt"

# The whole point of stage 1: `width * height - 1` must come out left-leaning,
# with precedence from the grammar and associativity from the fold. A `-` whose
# left is a `Binary` and whose right is a `Number` is that shape and no other.
tree=$(bounded "$phx" --tree "$root/languages/calc/calc-c.phx" "$root/languages/calc/programs/sum.calc" 2>/dev/null)
if printf '%s' "$tree" | grep -q "op: \"-\"" \
   && printf '%s' "$tree" | grep -q "left: Binary" \
   && ! printf '%s' "$tree" | grep -q "expression"; then
    report pass "the fold associates to the left"
else
    report fail "the fold associates to the left"
fi
# `"expected"` was the whole expectation here, which a missing semicolon
# satisfies just as well -- it asserted that the file was refused and nothing
# about *why*. What the test is for is that `print` cannot be a variable, so
# the name and the position are what to insist on.
refuses "a reserved word as a name" "1:5: error: expected name, and found \"print\"" \
        "$root/languages/calc/calc-c.phx" "$root/languages/calc/tests/reserved.calc"
refuses "a character no rule matches" "nothing here matches" \
        "$root/languages/calc/calc-c.phx" "$root/languages/calc/tests/bad-token.calc"

echo "a file a description embeds"
# A backend that emits a language needs that language's runtime, and a
# description has nowhere to put one but a string literal.
# `languages/awk/awk-c.phx` had seven hundred lines of C that way -- unreadable,
# and **untestable**, because the C could not be compiled except through a
# program generated from it. `%embed` reads the file when the description is
# read and freezes it into whatever `-o` writes, so one file, no headers, no
# library still holds.
# Compared as bytes rather than as a shell string, because the file's own
# trailing newline is part of what was embedded.
bounded "$phx" --raw "$root/tests/grammars/embed.phx" "$root/tests/sources/zero.txt" \
       > "$tmp0/embedded.out" 2>/dev/null
{ cat "$root/tests/grammars/embedded.c"; printf 'int main(void) { return 0; }\n'; } \
       > "$tmp0/embedded.want"
if cmp -s "$tmp0/embedded.out" "$tmp0/embedded.want"; then
    report pass "the bytes of another file, under a name"
else
    report fail "the bytes of another file, under a name" \
                "$(diff "$tmp0/embedded.want" "$tmp0/embedded.out" | head -3 | tr '\n' ' ')"
fi
refuses "a file that is not there" "cannot read" \
        "$root/tests/grammars/embed-missing.phx"
refuses "two files under one name" "is already embedded" \
        "$root/tests/grammars/embed-twice.phx"

# The embedded file is a file the description was assembled from, so a Makefile
# that rebuilds on a change wants it listed.
if bounded "$phx" --imports "$root/languages/awk/awk-c.phx" 2>/dev/null \
   | grep -q 'awk-runtime\.c'; then
    report pass "--imports names it"
else
    report fail "--imports names it"
fi

# And the point of the whole thing: the runtime is a C file now, so it can be
# compiled on its own -- which is how it was written and how it was checked
# against awk before anything embedded it.
if cc -fsyntax-only -xc "$root/languages/awk/awk-runtime.c" 2>/dev/null; then
    report pass "and awk's runtime compiles on its own"
else
    report fail "and awk's runtime compiles on its own"
fi

echo "what a source includes"
# `%include` is `%import` one level down: for the language being described
# rather than for the description. It cannot be a pass -- a pass walks one tree
# that has already been read -- so it is a directive the reader acts on, and
# these are the four new ways a reader that follows files can fail.
inc="$root/tests/grammars/includes.phx"
src="$root/tests/sources/includes"

# shows <what> <expected> <args...> -- the `show` pass over the spliced tree.
shows() {
    what=$1; _want=$2; shift 2
    prints "$what" "$_want" --run show --show show "$@"
}

shows "a file spliced in where the include stood" \
      "a=1 c=3 d=4 b=2" "$inc" "$src/main.inc"
# Read once however many ways it is reached: `twice.inc` names `second.inc`,
# which names `third.inc`, and then names `third.inc` itself.
shows "a file reached twice is read once" \
      "c=3 d=4 e=5" "$inc" "$src/twice.inc"
# Which is also the whole of why a cycle ends -- there is nothing to detect.
shows "two files that include each other" \
      "q=2 p=1" "$inc" "$src/cycle-a.inc"
# Three spellings of one file, and identity is what decides, not the letters:
# `second.inc`, `./second.inc` and `elsewhere/../second.inc`.
shows "three spellings of one file are one file" \
      "c=3 d=4 f=7" "$inc" "$src/spellings.inc"
shows "found on the search path, not beside the includer" \
      "y=8 z=9" "-I" "$src/elsewhere" "$inc" "$src/needs-path.inc"
shows "--no-includes leaves the include in the tree" \
      "a=1 use second.inc b=2" "--no-includes" "$inc" "$src/main.inc"

refuses "an included file that is not there" "cannot read the included file" \
        "$inc" "$src/absent.inc"
refuses "an include where one value is wanted" "where one value is wanted" \
        "$root/tests/grammars/include-in-a-field.phx" "$src/in-a-field.inc"
refuses "an included file with a two-part root" "nothing to splice in" \
        "$root/tests/grammars/include-two-part-root.phx" "$src/two-part.inc"
refuses "an include that is the whole file" "nothing here for it to be spliced into" \
        "$root/tests/grammars/include-whole-file.phx" "$src/whole-file.inc"
refuses "%include naming a node nothing builds" "nothing in this description builds" \
        "$root/tests/grammars/include-unknown-node.phx"
refuses "%include naming a field that is not one" "which is not a field of" \
        "$root/tests/grammars/include-unknown-field.phx"
refuses "%include declared twice" "already declared" \
        "$root/tests/grammars/include-twice.phx"

# A message from inside an included file has to name *that* file and its own
# line, which is the whole reason the text is joined rather than parsed apart.
out=$(bounded "$phx" --quiet "$inc" "$src/uses-broken.inc" 2>&1)
if printf '%s' "$out" | grep -q "broken.inc:2:"; then
    report pass "a fault in an included file names it"
else
    report fail "a fault in an included file names it" "$(printf '%s' "$out" | head -1)"
fi

echo "names the parse keeps"
# `%names`: `t * x;` declares when `t` was declared a type above it, and
# multiplies when it was not. The shape of the tree is the answer, so the node
# types are read off it in order. Each of the three things below was broken on
# purpose when this was written, and each broke this line: no undo made
# `maybe u;` declare `u`, no scope left the block's `t` hiding the type after
# it, no guard made every `a * b` a declaration, and binding when the node was
# built rather than when its name was read made `let t = t;` end in `IsType`.
want="Program Product Type Var Block Var Product Var Maybe Product Type Var Block Let IsName"
got=$(bounded "$phx" "$root/tests/grammars/names.phx" "$root/tests/sources/names.txt" 2>&1 \
      | grep -oE '[A-Z][a-zA-Z]+$' | tr '\n' ' ' | sed 's/ $//')
if [ "$got" = "$want" ]; then
    report pass "a guard asks what the parse declared, a scope ends, a failure undoes"
else
    report fail "a guard asks what the parse declared, a scope ends, a failure undoes" \
                "wanted '$want', got '$got'"
fi
refuses "%names binding a node nothing builds" "nothing in this description builds" \
        "$root/tests/grammars/names-unknown-node.phx"
refuses "%names binding a field that is not one" "is not a field of" \
        "$root/tests/grammars/names-unknown-field.phx"
refuses "%names binding a field the action computes" "no moment to bind it at" \
        "$root/tests/grammars/names-computed-field.phx"
refuses "%names guarding more than one token" "which is more than one token" \
        "$root/tests/grammars/names-guard-not-a-token.phx"
refuses "%names scoping a rule nobody wrote" "which is not a rule" \
        "$root/tests/grammars/names-scope-not-a-rule.phx"
warns "%names that nothing asks" "guards nothing" \
      "$root/tests/grammars/names-guards-nothing.phx"

echo "where a node came from"
# `$pos` is the one name in a pass that is not a field, an attribute or a
# binding. It answers a node -- Position(line, column, file) -- so reading part
# of one is an ordinary field read, and `.` over a list already means "that of
# each", which is what a table with a row per statement is written out of.
prints "a position names its own file and line" \
       "$src/main.inc:1 $src/second.inc:1 $src/third.inc:1 $src/main.inc:3 " \
       --driver where "$inc" "$src/main.inc"
prints "and its column" "1 1 1 1 " --driver columns "$inc" "$src/main.inc"

# `sizes` and `bytes` over a list: the size of each element, and each of a
# column of numbers as fixed-width bytes. Both exist because a table in a
# binary format is a column, and the alternative was the same line of notation
# written once per node type that could be a row.
widths=$(bounded "$phx" --raw --driver widths "$inc" "$src/main.inc" 2>/dev/null \
         | od -An -tu1 | tr '\n' ' ' | tr -s ' ' | sed 's/^ //;s/ $//')
if [ "$widths" = "3 0 3 0 3 0 3 0" ]; then
    report pass "sizes, and bytes over a list"
else
    report fail "sizes, and bytes over a list" "got '$widths'"
fi

refuses "a field called 'pos'" "what every node says its position with" \
        "$root/tests/grammars/pos-is-a-field.phx"
refuses "a clause defining 'pos'" "a clause cannot define one" \
        "$root/tests/grammars/pos-is-an-attribute.phx"

echo "patterns over lists"
# A pattern for every value kind. A value can be a list, so a pattern has to be
# able to be one -- and without it there is no way to ask about a field holding
# several things, which is exactly the question an optimisation asks.
lp="$root/tests/grammars/list-patterns.phx"
prints "a list of one"        "one: 5"        "$lp" "$root/tests/sources/one.txt"
prints "a list of two"        "two: 3 5"      "$lp" "$root/tests/sources/two-cells.txt"
prints "a value inside one"   "seven and 3"   "$lp" "$root/tests/sources/pair.txt"
prints "a longer list"        "many"          "$lp" "$root/tests/sources/three-cells.txt"
refuses "a list pattern above a narrower one" "can never match" \
        "$root/tests/grammars/list-pattern-order.phx"

echo "rewrites"
# A pass decorates; a rewrite replaces. Both halves were already here --
# patterns match on shape and bind, the evaluator builds nodes -- so what this
# adds is a traversal that puts the answer back.
fold="$root/tests/grammars/fold.phx"
arith="$root/tests/sources/arithmetic.txt"
prints "the tree as it was read" "((2 + (3 * 4)) + 1)" --driver plain   "$fold" "$arith"
prints "folded bottom-up"        "15"                  --driver folded  "$fold" "$arith"
# Top-down asks about the outside before the inside, and stops one level short.
# Which is why the strategy is a word rather than a default.
prints "and top-down, which is not the same" "((2 + 12) + 1)" \
       --driver partial "$fold" "$arith"

# **A node's span is the syntax that built it**, which is not the same as
# everything underneath it. `2 * 3` is three tokens at columns 1, 3 and 5, and
# the Binary claims 1:3..1:5 -- from its *operator*, not from its left operand
# -- because the action that builds it runs inside a repetition and `$$` was
# built on an earlier turn. Small enough to check by counting, which the
# thirteen-column version of this was not.
prints "a node's span is the syntax that built it" \
       "(2@1:1..1:1 * 3@1:5..1:5)@1:3..1:5" \
       --driver spans "$fold" "$root/tests/sources/one-op.txt"

# A node built by a rewrite takes the position of the node it replaced --
# docs/reference.md says so, run.c copies the span into the builder on purpose,
# and until now nothing ran it.
#
# The span is **derived rather than pasted**: whatever the root claims before
# the fold is what the folded node has to claim after it. A literal here would
# have been a snapshot of the rule above, and the two would have had to be kept
# in step by hand.
before=$(bounded "$phx" --driver spans "$fold" "$arith" 2>/dev/null)
rootspan=${before##*@}
after=$(bounded "$phx" --driver folded-spans "$fold" "$arith" 2>/dev/null)
if [ -n "$rootspan" ] && [ "$after" = "15@$rootspan" ]; then
    report pass "and a rewritten node keeps the one it replaced"
else
    report fail "and a rewritten node keeps the one it replaced" \
                "root claimed '$rootspan', the folded node said '$after'"
fi

refuses "an innermost rewrite that never settles" "and is still going" \
        "$root/tests/grammars/rewrite-runaway.phx" "$root/tests/sources/one.txt"
refuses "a rewrite reading an attribute" "rather than what a pass worked out" \
        "$root/tests/grammars/rewrite-reads-attribute.phx"
refuses "a rewrite named like a pass" "is a pass as well as a rewrite" \
        "$root/tests/grammars/rewrite-named-twice.phx"

echo "what a node answers otherwise"
# A clause is keyed on a node type, and some attributes are answered the same
# way by nearly every type -- `languages/pascal/pascal.phx` wrote
# `type = "void"` twenty-one times so that a node above could read a type
# without asking which kind of statement it was. `otherwise` is the one clause
# that says it, and it is still a clause about a node: the general one.
ow="$root/tests/grammars/otherwise.phx"
prints "a node with none of its own takes the default" \
       "a row: a seven, something" "$ow" "$root/tests/sources/seven-two.txt"
refuses "two answers to what a node answers otherwise" "already has an 'otherwise'" \
        "$root/tests/grammars/otherwise-twice.phx"
refuses "an 'otherwise down'" "is what it hands its children" \
        "$root/tests/grammars/otherwise-down.phx"

# Pascal is where it came from, and the 35 programs above are what says it
# still means the same thing. This says the twenty-one are gone.
if [ "$(grep -c ': type = "void"' "$root/languages/pascal/pascal.phx")" = "0" ]; then
    report pass "and Pascal says it once"
else
    report fail "and Pascal says it once" "'type = \"void\"' is still written out"
fi

echo "drivers"
refuses "a driver in the wrong order" "nothing before it defines one" \
        "$root/tests/grammars/misordered-driver.phx"
refuses "a driver naming no such stage" "no pass or rewrite of that name" \
        "$root/tests/grammars/no-such-pass.phx"
refuses "a driver answering with nothing" "none of its passes defines one" \
        "$root/tests/grammars/driver-no-answer.phx"
refuses "two drivers of one name" "two drivers called" \
        "$root/tests/grammars/duplicate-driver.phx"
# **A bare `$name` that nothing could answer**, refused when the description
# is read, since 2026-09-23. Before, it was looked up only as the pass ran, so
# it was reported once per node that reached it, or never. ROADMAP 5 has the
# two sightings these reproduce: a name nothing defines, and a thread read by
# a pass other than its own. The third holds every kind of bare name that
# can answer, so the check stays as generous as the lookup it guards.
refuses "a bare name nothing could answer" "nothing can be called 'sig' here" \
        "$root/tests/grammars/bare-name-nothing.phx"
refuses "a bare name that is another pass's thread" "lives only in that pass's walk" \
        "$root/tests/grammars/bare-name-another-pass-thread.phx"
accepts "and every kind of bare name that can answer" \
        "$root/tests/grammars/bare-name-every-kind.phx"
# **A stage run `until` an attribute settles**, since 2026-09-23: ROADMAP
# 2.5's fixpoint, written in the driver. `languages/z80/` is the customer, and
# its sizes are pinned under Z80 below. These are what is refused: a rewrite,
# which has nothing to settle; a start nobody left for the first round; a
# stage that does not define what it is waiting on; and one that never
# settles, which stops at the bound rather than running forever.
refuses "until, on a rewrite" "a rewrite defines no attribute to settle" \
        "$root/tests/grammars/until-a-rewrite.phx"
refuses "until, with nothing to start from" "nothing before it defines 'n' for the first round" \
        "$root/tests/grammars/until-no-start.phx"
refuses "until, on something the stage does not define" "'other' does not define 'n' on a node" \
        "$root/tests/grammars/until-not-defined.phx"
refuses "until, when it never settles" "'grow' ran 256 times and 'n' on the root was still changing" \
        "$root/tests/grammars/until-never-settles.phx" "$root/tests/sources/zero.txt"

# The default driver is the first declared, and it compiles.
if bounded "$phx" --quiet "$root/languages/calc/calc-c.phx" "$root/languages/calc/programs/sum.calc" \
        > /dev/null 2>&1; then
    report pass "the default driver runs"
else
    report fail "the default driver runs"
fi

# A driver with no `->` is a validation run: it says nothing and answers with
# its status.
out=$(bounded "$phx" --driver check "$root/languages/calc/calc-c.phx" \
        "$root/languages/calc/programs/fizz.calc" 2>&1)
if [ -z "$out" ]; then
    report pass "a check driver says nothing"
else
    report fail "a check driver says nothing" "printed: $out"
fi

# The whole reason stage 3 exists: typecheck's message renders the offending
# expression with lib/expression.phx's `show`, which is only readable because
# the driver runs `show` first.
msg=$(bounded "$phx" --quiet "$root/languages/calc/calc-c.phx" \
        "$root/languages/calc/tests/print-a-bool.calc" 2>&1)
if printf '%s' "$msg" | grep -qF "(n < 2) is bool"; then
    report pass "a pass reading another pass's work"
else
    report fail "a pass reading another pass's work" "$(printf '%s' "$msg" | head -1)"
fi

echo "passes"
accepts "the calculator's passes" "$root/languages/calc/calc-c.phx"
accepts "typecheck accepts fizz"  --run typecheck --show type \
        "$root/languages/calc/calc-c.phx" "$root/languages/calc/programs/fizz.calc"
refuses "an int used as a condition" "wants a bool" --run typecheck --show type \
        "$root/languages/calc/calc-c.phx" "$root/languages/calc/tests/int-as-condition.calc"
refuses "printing a bool" "print wants an int" --run typecheck --show type \
        "$root/languages/calc/calc-c.phx" "$root/languages/calc/tests/print-a-bool.calc"
refuses "an undefined name"  "is not defined" \
        --run eval "$root/languages/calc/calc-c.phx" "$root/languages/calc/tests/undefined.calc"
refuses "division by zero"   "division by zero" \
        --run eval "$root/languages/calc/calc-c.phx" "$root/languages/calc/tests/divzero.calc"

# One mistake should produce one message. The cascade this guards against --
# a check firing, then the arithmetic above it complaining about the nil it
# left, then every node above that -- is what `checks are guards` is for.
n=$(bounded "$phx" --run eval "$root/languages/calc/calc-c.phx" \
        "$root/languages/calc/tests/undefined.calc" 2>&1 | grep -c "error:")
if [ "$n" -eq 1 ]; then
    report pass "one mistake, one message"
else
    report fail "one mistake, one message" "got $n errors, wanted 1"
fi

# ---------------------------------------------------------------------------
# docs/semantics.md itself.
#
# That page is the specification -- what the meta-language's arithmetic,
# comparison, text and formatting *are*, in Phoenix's own terms, "so that a
# second backend has something exact to agree with". `eval.c`'s header says the
# two are changed together or not at all, and nothing checked that: every other
# test here asks about a language being described rather than about the
# notation describing it, so the page and the code could have drifted a claim
# at a time with the suite still green.

echo "the specification, claim by claim"

claims=$(grep -c '^ *! ' "$root/tests/grammars/semantics.phx")
accepts "$claims claims from docs/semantics.md hold" \
        "$root/tests/grammars/semantics.phx" "$root/tests/sources/one-node.txt"

# The half a specification that only says what works leaves out -- and the half
# two backends drift apart in, because an implicit conversion one of them makes
# and the other does not is exactly the silent disagreement that page is for.
refusals="$root/tests/grammars/semantics-refused.phx"
out=$(bounded "$phx" --quiet "$refusals" "$root/tests/sources/one-node.txt" 2>&1)
missing=""
for want in "there is no conversion" \
            "does not join text" \
            "does not narrow a float" \
            "overflows a 64-bit integer" \
            "division by zero" \
            "no order across kinds" \
            "wants a boolean" \
            "nil has no written form" \
            "a list has no written form" \
            "'...' wants a list"; do
    printf '%s' "$out" | grep -qF -- "$want" || missing="$missing '$want'"
done
if [ -n "$missing" ]; then
    report fail "and every refusal it names" "no message matching$missing"
elif bounded "$phx" --quiet "$refusals" "$root/tests/sources/one-node.txt" >/dev/null 2>&1; then
    report fail "and every refusal it names" "the description was accepted"
else
    report pass "and every refusal it names"
fi

# docs/reference.md § 11, the same way. The library was held by nothing:
# eighteen of its twenty-two functions had no executable check at all, and that
# page is full of the claims that rot -- `each` running to the longer of two
# lists is written down *because* taking the shorter turned `abs(i)` into
# `abs()`, and `lookup` comparing the way `=` compares is there because
# comparing text only meant an integer key never matched and never said so.
lclaims=$(grep -c '^ *! ' "$root/tests/grammars/library.phx")
accepts "$lclaims claims from docs/reference.md section 11 hold" \
        "$root/tests/grammars/library.phx" "$root/tests/sources/one-node.txt"

lrefusals="$root/tests/grammars/library-refused.phx"
lout=$(bounded "$phx" --quiet "$lrefusals" "$root/tests/sources/one-node.txt" 2>&1)
lmissing=""
for want in "does not narrow a float" \
            "cannot split on nothing" \
            "writes one to eight bytes, not 9" \
            "writes one to eight bytes, not 0" \
            "a float is four or eight bytes" \
            "'bitand' wants two integers" \
            '"9223372036854775808" does not fit in a 64-bit integer' \
            '"-9223372036854775809" does not fit in a 64-bit integer' \
            '"10000000000000000" does not fit in a 64-bit integer'; do
    printf '%s' "$lout" | grep -qF -- "$want" || lmissing="$lmissing [$want]"
done
if [ -z "$lmissing" ]; then
    report pass "and the refusals it names"
else
    report fail "and the refusals it names" "missing:$lmissing"
fi

# The records' *arithmetic*, which nothing ran until a sweep found nine stale
# counts on 2026-09-05 -- four drifted over three days, two of them two hours
# old. The prose in these documents is executed a dozen ways above; the numbers
# were executed by nobody. tests/counts.sh has the reasoning.
if cnt=$(harness "$root/tests/counts.sh" 2>&1); then
    n=$(printf '%s' "$cnt" | grep -c '^  ok')
    report pass "$n counts in the records match the tree"
else
    report fail "counts in the records match the tree"
    printf '%s\n' "$cnt" | grep '^  FAIL' | sed 's/^/      /' | head -10
fi

# The conformance rule, applied to the page the rule is *about*: the same
# claims, and the same complaints about breaking them, from `phx` and from a
# compiler `phx` wrote.
if bounded "$phx" "$root/tests/grammars/semantics.phx" -o "$tmp0/sem.c" 2>/dev/null \
   && cc -o "$tmp0/semc" "$tmp0/sem.c" 2>/dev/null \
   && bounded "$phx" "$refusals" -o "$tmp0/semr.c" 2>/dev/null \
   && cc -o "$tmp0/semrc" "$tmp0/semr.c" 2>/dev/null; then

    if bounded "$tmp0/semc" "$root/tests/sources/one-node.txt" >/dev/null 2>&1; then
        report pass "and hold in a compiler phx wrote"
    else
        report fail "and hold in a compiler phx wrote"
    fi

    # The library's claims through the same two implementations.
    if bounded "$phx" "$root/tests/grammars/library.phx" -o "$tmp0/lib.c" 2>/dev/null \
       && cc -o "$tmp0/libc" "$tmp0/lib.c" 2>/dev/null \
       && bounded "$tmp0/libc" "$root/tests/sources/one-node.txt" >/dev/null 2>&1; then
        report pass "and the library's do too"
    else
        report fail "and the library's do too"
    fi

    bounded "$phx" --quiet "$refusals" "$root/tests/sources/one-node.txt" 2>"$tmp0/sem-phx" >/dev/null
    bounded "$tmp0/semrc" "$root/tests/sources/one-node.txt" 2>"$tmp0/sem-cc" >/dev/null
    if cmp -s "$tmp0/sem-phx" "$tmp0/sem-cc"; then
        report pass "with the same complaints, byte for byte"
    else
        report fail "with the same complaints, byte for byte" \
                    "$(diff "$tmp0/sem-phx" "$tmp0/sem-cc" | head -2 | tr '\n' ' ')"
    fi
else
    report fail "and hold in a compiler phx wrote" "it did not build"
fi

# ---------------------------------------------------------------------------
# The conformance rule from docs/semantics.md, made a test rather than a hope:
# one .phx, interpreted and through both backends, must give the same answer.

want=$(bounded "$phx" --run eval "$root/languages/calc/calc-c.phx" "$root/languages/calc/programs/sum.calc" 2>/dev/null)
if [ "$want" = "97" ]; then
    report pass "interpreted"
else
    report fail "interpreted" "got '$want', wanted 97"
fi

tmp="$root/build/suite-2"; rm -rf "$tmp"; mkdir -p "$tmp"

# `{ statement }` matched exactly once must still be a list. The `.phx` author
# cannot know how many statements a block will hold, so the grammar decides the
# shape and not the input.
if bounded "$phx" --quiet --run emit-c "$root/languages/calc/calc-c.phx" \
        "$root/languages/calc/tests/one-statement-block.calc" >/dev/null 2>&1; then
    report pass "a block of exactly one statement"
else
    report fail "a block of exactly one statement"
fi

# docs/semantics.md's headline, as a test: Phoenix's division is floored and
# C's truncates, so a language that does not say which it means gets two
# answers from the same program. calc says truncating, in both passes.
neg_i=$(bounded "$phx" --run eval "$root/languages/calc/calc-c.phx" \
        "$root/languages/calc/tests/negative-division.calc" 2>/dev/null)
if bounded "$phx" --run emit-c "$root/languages/calc/calc-c.phx" \
        "$root/languages/calc/tests/negative-division.calc" > "$tmp/neg.c" 2>/dev/null \
   && cc -o "$tmp/neg" "$tmp/neg.c" 2>/dev/null; then
    neg_c=$(bounded "$tmp/neg")
    if [ "$neg_i" = "-3" ] && [ "$neg_c" = "-3" ]; then
        report pass "negative division agrees, and truncates"
    else
        report fail "negative division agrees, and truncates" \
                    "interpreted '$neg_i', compiled '$neg_c', wanted -3 both"
    fi
else
    report fail "negative division agrees, and truncates" "it did not compile"
fi

# Control flow: the compiled program has to actually run and be right.
if bounded "$phx" --run emit-c "$root/languages/calc/calc-c.phx" "$root/languages/calc/programs/fizz.calc" \
        > "$tmp/fizz.c" 2>/dev/null \
   && cc -Wall -Werror -o "$tmp/fizz" "$tmp/fizz.c" 2>/dev/null; then
    if ! got=$(bounded "$tmp/fizz" 2>&1); then
        report fail "a loop and a branch, compiled and run" \
                    "it exited nonzero: $(printf '%s' "$got" | tr '\n' ' ')"
        got=
    fi
    got=$(printf '%s' "$got" | tr '\n' ' ')
    # No trailing space: `$(...)` strips the final newline before `tr` sees it.
    if [ "$got" = "1 2 300 4 5 300 7 8 300 10 11 300 13 14 300" ]; then
        report pass "a loop and a branch, compiled and run"
    else
        report fail "a loop and a branch, compiled and run" "got: $got"
    fi
else
    report fail "a loop and a branch, compiled and run" "it did not compile cleanly"
fi

# The interpreter's boundary, said out loud rather than failing obscurely.
refuses "a loop refuses to be interpreted" "cannot be interpreted" \
        --run eval "$root/languages/calc/calc-c.phx" "$root/languages/calc/programs/fizz.calc"

if bounded "$phx" --run emit-c "$root/languages/calc/calc-c.phx" "$root/languages/calc/programs/sum.calc" \
        > "$tmp/out.c" 2>/dev/null \
   && cc -o "$tmp/out" "$tmp/out.c" 2>/dev/null; then
    if ! got=$(bounded "$tmp/out" 2>&1); then
        report fail "through the C backend, same answer" \
                    "it exited nonzero: $(printf '%s' "$got" | tr '\n' ' ')"
        got=
    fi
    if [ "$got" = "$want" ]; then
        report pass "through the C backend, same answer"
    else
        report fail "through the C backend, same answer" "got '$got', wanted '$want'"
    fi
else
    report fail "through the C backend, same answer" "it did not compile"
fi

# ---------------------------------------------------------------------------
# The third leg, and the one that reaches a loop.
#
# `--run eval` cannot interpret a branch or a loop -- an attribute is computed
# once per node in one walk -- so up to here every calc program with control
# flow in it was checked by *one* implementation, against a string somebody had
# typed into this file. Two emit passes are two implementations, and they can
# be held against each other where the interpreter cannot go.
#
# awk is the second backend rather than Solveig because it needs nothing that
# is not needed already: the Makefile builds phoenix/runtime.h by piping
# through `awk`, so `make` does not run without one, and `solas` is not in this
# repository at all. And awk's numbers are doubles, so it is wrong in a
# *different* direction from C -- which is the whole reason a pair is worth
# more than either of them twice.

accepts "the awk backend reads" "$root/languages/calc/calc-awk.phx"

if bounded "$phx" --run emit-awk "$root/languages/calc/calc-awk.phx" \
        "$root/languages/calc/programs/sum.calc" > "$tmp/sum.awk" 2>/dev/null; then
    got=$(bounded awk -f "$tmp/sum.awk" 2>&1)
    if [ "$got" = "$want" ]; then
        report pass "through the awk backend, same answer"
    else
        report fail "through the awk backend, same answer" "got '$got', wanted '$want'"
    fi
else
    report fail "through the awk backend, same answer" "it did not emit"
fi

# docs/semantics.md's headline, met a second time in a second host. C's `/`
# truncates and happens to agree with calc; awk's is floating division and does
# not, so this backend has to write the model out as `int(a / b)`. The same
# program, the same -3.
if bounded "$phx" --run emit-awk "$root/languages/calc/calc-awk.phx" \
        "$root/languages/calc/tests/negative-division.calc" > "$tmp/neg.awk" 2>/dev/null; then
    got=$(bounded awk -f "$tmp/neg.awk" 2>&1)
    if [ "$got" = "-3" ]; then
        report pass "and truncates in a host whose / does not"
    else
        report fail "and truncates in a host whose / does not" "got '$got', wanted -3"
    fi
else
    report fail "and truncates in a host whose / does not" "it did not emit"
fi

# backends_agree <what> <program> -- one description, both emit passes, and the
# two compiled programs run and compared with each other. No expected string:
# the answer is what two implementations independently arrived at, which is the
# conformance rule with the interpreter's leg replaced rather than dropped.
backends_agree() {
    _what=$1; _prog=$2
    if ! bounded "$phx" --run emit-awk "$root/languages/calc/calc-awk.phx" "$_prog" \
            > "$tmp/two.awk" 2>/dev/null; then
        report fail "$_what" "the awk backend did not emit"
        return
    fi
    if ! bounded "$phx" --run emit-c "$root/languages/calc/calc-c.phx" "$_prog" \
            > "$tmp/two.c" 2>/dev/null \
       || ! cc -Wall -Werror -o "$tmp/two" "$tmp/two.c" 2>/dev/null; then
        report fail "$_what" "the C backend did not compile cleanly"
        return
    fi
    # Both statuses are checked, and both streams captured, because neither
    # half of that is optional: a program that dies prints nothing, and two
    # programs that both die print the same nothing. COMPLETED.md already has
    # a row for the version of this mistake that reached bench/run.sh.
    if ! _a=$(bounded awk -f "$tmp/two.awk" 2>&1); then
        report fail "$_what" "awk exited nonzero: $(printf '%s' "$_a" | tr '\n' ' ')"
        return
    fi
    if ! _c=$(bounded "$tmp/two" 2>&1); then
        report fail "$_what" "the compiled C exited nonzero: $(printf '%s' "$_c" | tr '\n' ' ')"
        return
    fi
    _a=$(printf '%s' "$_a" | tr '\n' ' ')
    _c=$(printf '%s' "$_c" | tr '\n' ' ')
    if [ "$_a" = "$_c" ]; then
        report pass "$_what"
    else
        report fail "$_what" "awk said '$_a', C said '$_c'"
    fi
}

backends_agree "a loop and a branch, two backends, one answer" \
               "$root/languages/calc/programs/fizz.calc"
backends_agree "a loop whose body is one statement, likewise" \
               "$root/languages/calc/tests/one-statement-block.calc"
backends_agree "and the operators the module brought" \
               "$root/languages/calc/programs/logic.calc"
# `<>` and `or` are spelled by clauses of their own in both backends -- `!=`
# and `||` -- and no other calc program in the tree reaches either. They had
# nothing holding them until this one.
backends_agree "and the two spellings nothing else exercised" \
               "$root/languages/calc/tests/or-and-noteq.calc"

# The Solveig backend is parked. Its example is still read, so the notation
# cannot drift out from under it -- but nothing runs `solas`, and the round
# trip happens only when it is asked for by name:
#
#     PHX_TEST_SOLVEIG=1 make test
#
# Auto-detecting a sibling checkout is how a test suite comes to fail for
# reasons that have nothing to do with the project it is testing.
accepts "the parked Solveig example" "$root/languages/calc/calc-solveig.phx"

if [ -n "${PHX_TEST_SOLVEIG:-}" ]; then
    SOL=${SOLVEIG:-$root/../Solveig}
    if [ -x "$SOL/bin/solas" ]; then
        if bounded "$phx" --run emit-sol "$root/languages/calc/calc-solveig.phx" \
                "$root/languages/calc/programs/sum.calc" > "$tmp/out.sol" 2>/dev/null \
           && "$SOL/bin/solas" "$tmp/out.sol" -o "$tmp/out.sob" >/dev/null 2>&1; then
            got=$(bounded "$SOL/bin/solvm" "$tmp/out.sob")
            if [ "$got" = "$want" ]; then
                report pass "through the Solveig backend, same answer"
            else
                report fail "through the Solveig backend, same answer" \
                            "got '$got', wanted '$want'"
            fi
        else
            report fail "through the Solveig backend, same answer" "it did not compile"
        fi
    else
        report fail "through the Solveig backend, same answer" "no solas at $SOL"
    fi
fi

# ---------------------------------------------------------------------------
# A description written out as its own compiler. The property being checked is
# not that it works -- it is that it is **the same**: the generated program runs
# the same matcher and evaluator phx runs, over frozen tables, so a byte of
# difference between them would mean two implementations had appeared.

echo "generated compilers"

if bounded "$phx" "$root/languages/calc/calc-c.phx" -o "$tmp0/calc.c" 2>/dev/null; then
    report pass "calc writes out as C"
else
    report fail "calc writes out as C"
fi

if cc -o "$tmp0/calcc" "$tmp0/calc.c" 2>/dev/null; then
    report pass "one file, no flags, no headers"

    for f in sum fizz logic; do
        bounded "$phx" "$root/languages/calc/calc-c.phx" "$root/languages/calc/programs/$f.calc" \
            > "$tmp0/by-phx" 2>/dev/null
        bounded "$tmp0/calcc" "$root/languages/calc/programs/$f.calc" > "$tmp0/by-cc" 2>/dev/null
        if cmp -s "$tmp0/by-phx" "$tmp0/by-cc"; then
            report pass "$f.calc: identical to phx, byte for byte"
        else
            report fail "$f.calc: identical to phx, byte for byte"
        fi
    done

    # The generated program is a compiler, so what it writes has to compile.
    if bounded "$tmp0/calcc" "$root/languages/calc/programs/fizz.calc" > "$tmp0/fizz.c" 2>/dev/null \
       && cc -Wall -Werror -o "$tmp0/fizz" "$tmp0/fizz.c" 2>/dev/null; then
        if ! got=$(bounded "$tmp0/fizz" 2>&1); then
            report fail "and what it writes runs" \
                        "it exited nonzero: $(printf '%s' "$got" | tr '\n' ' ')"
            got=
        fi
        got=$(printf '%s' "$got" | tr '\n' ' ')
        if [ "$got" = "1 2 300 4 5 300 7 8 300 10 11 300 13 14 300" ]; then
            report pass "and what it writes runs"
        else
            report fail "and what it writes runs" "got: $got"
        fi
    else
        report fail "and what it writes runs" "it did not compile"
    fi

    # Diagnostics still point into the description, from a program the
    # description is no longer beside.
    msg=$(bounded "$tmp0/calcc" "$root/languages/calc/tests/print-a-bool.calc" 2>&1)
    if printf '%s' "$msg" | grep -qF "(n < 2) is bool"; then
        report pass "its diagnostics survive the freezing"
    else
        report fail "its diagnostics survive the freezing" "$msg"
    fi
else
    report fail "one file, no flags, no headers" "it did not compile"
fi

# **A literal may hold a NUL**, and three kinds of thing here can be one: a
# grammar literal, a pattern and a template. The length beside each is what
# says how long it is, and writing them out with `strlen` carried a shorter
# string into the generated compiler while the length still said otherwise --
# so it read past the end of a string `phx` never had. A description emitting a
# binary format is full of these, and this is the shape of the one failure `-o`
# exists not to have.
if bounded "$phx" "$root/tests/grammars/nul-literal.phx" -o "$tmp0/nul.c" 2>/dev/null \
   && cc -o "$tmp0/nulc" "$tmp0/nul.c" 2>/dev/null; then
    bounded "$phx" --raw "$root/tests/grammars/nul-literal.phx" \
           "$root/tests/sources/with-a-nul.txt" > "$tmp0/nul-phx" 2>/dev/null
    bounded "$tmp0/nulc" --raw "$root/tests/sources/with-a-nul.txt" > "$tmp0/nul-cc" 2>/dev/null
    if cmp -s "$tmp0/nul-phx" "$tmp0/nul-cc" \
       && [ "$(wc -c < "$tmp0/nul-phx" | tr -d ' ')" = "11" ]; then
        report pass "a literal holding a NUL survives the freezing"
    else
        report fail "a literal holding a NUL survives the freezing" \
                    "$(od -c "$tmp0/nul-cc" | head -1)"
    fi
else
    report fail "a literal holding a NUL survives the freezing" "it did not build"
fi

# The conformance rule, over the one backend that emits **bytes**. Everything
# above compares text a person could read; a `.sob` is a binary format, so this
# is where a single wrong byte has nowhere to hide -- and it needs `--raw`,
# which a generated compiler has for the same reason `phx` does.
if bounded "$phx" "$root/languages/solveig/solveig-sob.phx" -o "$tmp0/sob.c" 2>/dev/null \
   && cc -o "$tmp0/sobc" "$tmp0/sob.c" 2>/dev/null; then
    same=0; differ=0
    for f in "$root"/languages/solveig/tests/conformance/*.sol; do
        bounded "$phx" --raw --driver sob "$root/languages/solveig/solveig-sob.phx" "$f" \
               > "$tmp0/by-phx.sob" 2>/dev/null
        bounded "$tmp0/sobc" --raw --driver sob "$f" > "$tmp0/by-cc.sob" 2>/dev/null
        if cmp -s "$tmp0/by-phx.sob" "$tmp0/by-cc.sob"; then same=$((same+1))
        else differ=$((differ+1)); echo "  differs: $(basename "$f")"; fi
    done
    if [ "$differ" -eq 0 ] && [ "$same" -gt 0 ]; then
        report pass "$same .sob files, byte for byte, from phx and from a compiler it wrote"
    else
        report fail "a .sob written twice" "$same the same, $differ not"
    fi
else
    report fail "a .sob written twice" "the compiler did not build"
fi

# A rewrite is frozen into a generated compiler like everything else, and a
# driver names its stages without caring which kind each one is.
if bounded "$phx" "$root/tests/grammars/fold.phx" -o "$tmp0/fold.c" 2>/dev/null \
   && cc -o "$tmp0/foldc" "$tmp0/fold.c" 2>/dev/null; then
    a=$(bounded "$phx" --driver folded "$root/tests/grammars/fold.phx" "$arith" 2>/dev/null)
    b=$(bounded "$tmp0/foldc" --driver folded "$arith" 2>/dev/null)
    if [ "$a" = "$b" ] && [ "$a" = "15" ]; then
        report pass "a generated compiler runs a rewrite"
    else
        report fail "a generated compiler runs a rewrite" "phx '$a', it '$b'"
    fi
else
    report fail "a generated compiler runs a rewrite" "it did not build"
fi

# And a stage run `until` something settles: the loop is in the runtime, so a
# generated compiler has it, and the program that needs a fourth walk is the
# one that shows it. 131 bytes is the minimum, and 134 is one walk's answer.
if bounded "$phx" "$root/languages/z80/z80.phx" -o "$tmp0/z80.c" 2>/dev/null \
   && cc -o "$tmp0/z80c" "$tmp0/z80.c" 2>/dev/null; then
    three="$root/languages/z80/tests/oracle/three-rounds.z80"
    bounded "$phx" --raw --driver code "$root/languages/z80/z80.phx" "$three" \
           > "$tmp0/z80-phx" 2>/dev/null
    "$tmp0/z80c" --raw --driver code "$three" > "$tmp0/z80-cc" 2>/dev/null
    if cmp -s "$tmp0/z80-phx" "$tmp0/z80-cc" \
       && [ "$(wc -c < "$tmp0/z80-cc" | tr -d ' ')" = "131" ]; then
        report pass "a generated compiler runs a stage until it settles"
    else
        report fail "a generated compiler runs a stage until it settles" \
                    "$(wc -c < "$tmp0/z80-cc" | tr -d ' ') bytes"
    fi
else
    report fail "a generated compiler runs a stage until it settles" "it did not build"
fi

# An embedded file has to survive the freezing like anything else -- and it is
# the one thing here most likely to hold a byte that does not survive being
# written as a C literal.
if bounded "$phx" "$root/tests/grammars/embed.phx" -o "$tmp0/emb.c" 2>/dev/null \
   && cc -o "$tmp0/embc" "$tmp0/emb.c" 2>/dev/null; then
    bounded "$phx" --raw "$root/tests/grammars/embed.phx" "$root/tests/sources/zero.txt" \
           > "$tmp0/emb-phx" 2>/dev/null
    "$tmp0/embc" --raw "$root/tests/sources/zero.txt" > "$tmp0/emb-cc" 2>/dev/null
    if cmp -s "$tmp0/emb-phx" "$tmp0/emb-cc"; then
        report pass "an embedded file survives the freezing"
    else
        report fail "an embedded file survives the freezing"
    fi
else
    report fail "an embedded file survives the freezing" "it did not build"
fi

# The table is kept by the matcher, which a generated compiler carries, and
# which rules scope and guard are flags on its rules: all three have to be
# written out, or the compiler parses `t * x;` the way it would without them.
if bounded "$phx" "$root/tests/grammars/names.phx" -o "$tmp0/names.c" 2>/dev/null \
   && cc -o "$tmp0/namesc" "$tmp0/names.c" 2>/dev/null; then
    bounded "$phx" "$root/tests/grammars/names.phx" "$root/tests/sources/names.txt" \
           > "$tmp0/names-phx" 2>/dev/null
    "$tmp0/namesc" "$root/tests/sources/names.txt" > "$tmp0/names-cc" 2>/dev/null
    if cmp -s "$tmp0/names-phx" "$tmp0/names-cc"; then
        report pass "a generated compiler keeps the names"
    else
        report fail "a generated compiler keeps the names"
    fi
else
    report fail "a generated compiler keeps the names" "it did not build"
fi

# A generated compiler follows includes too, and has to: whether one file
# names another is a property of the language, not of who is compiling it. So
# it takes `-I` for the same reason `phx` does, and the two must agree about
# what the spliced tree is.
if bounded "$phx" "$root/tests/grammars/includes.phx" -o "$tmp0/inc.c" 2>/dev/null \
   && cc -o "$tmp0/incc" "$tmp0/inc.c" 2>/dev/null; then
    a=$(bounded "$phx" -I "$src/elsewhere" "$root/tests/grammars/includes.phx" \
        "$src/needs-path.inc" 2>/dev/null)
    b=$(bounded "$tmp0/incc" -I "$src/elsewhere" "$src/needs-path.inc" 2>/dev/null)
    if [ "$a" = "$b" ] && [ "$a" = "y=8 z=9" ]; then
        report pass "a generated compiler follows an include"
    else
        report fail "a generated compiler follows an include" "phx '$a', it '$b'"
    fi

    # And it says where a node came from, which is the target file's position
    # rather than anything frozen into the tables.
    a=$(bounded "$phx" -I "$src/elsewhere" --driver where "$root/tests/grammars/includes.phx" \
        "$src/needs-path.inc" 2>/dev/null)
    b=$(bounded "$tmp0/incc" -I "$src/elsewhere" --driver where "$src/needs-path.inc" 2>/dev/null)
    if [ "$a" = "$b" ] && [ "$a" = "$src/elsewhere/far.inc:1 $src/needs-path.inc:2 " ]; then
        report pass "and agrees about where each node came from"
    else
        report fail "and agrees about where each node came from" "phx '$a', it '$b'"
    fi

    missing=$(bounded "$tmp0/incc" "$src/absent.inc" 2>&1)
    if printf '%s' "$missing" | grep -qF "cannot read the included file"; then
        report pass "and says so when the file is not there"
    else
        report fail "and says so when the file is not there" "$missing"
    fi
else
    report fail "a generated compiler follows an include" "it did not build"
fi

# Pascal, the same way round.
if bounded "$phx" "$root/languages/pascal/pascal-outline.phx" -o "$tmp0/pascal.c" 2>/dev/null \
   && cc -o "$tmp0/pas" "$tmp0/pascal.c" 2>/dev/null; then
    a=$(bounded "$phx" "$root/languages/pascal/pascal-outline.phx" "$root/languages/pascal/tests/grammar/features.pas" 2>/dev/null)
    b=$(bounded "$tmp0/pas" "$root/languages/pascal/tests/grammar/features.pas" 2>/dev/null)
    if [ "$a" = "$b" ] && printf '%s' "$b" | grep -qF "packed array [1..80] of char"; then
        report pass "a Pascal compiler, and it agrees with phx"
    else
        report fail "a Pascal compiler, and it agrees with phx"
    fi

    if bounded "$tmp0/pas" "$root/languages/pascal/tests/grammar/unclosed.pas" >/dev/null 2>&1; then
        report fail "and it still refuses a broken program"
    else
        report pass "and it still refuses a broken program"
    fi
else
    report fail "a Pascal compiler, and it agrees with phx" "it did not build"
fi

# ---------------------------------------------------------------------------
# Pascal to C, and then the whole way: phx writes a Pascal compiler, cc builds
# it, that compiler compiles a Pascal program to C, cc builds that, and the
# program runs and is right. Nothing in the chain but cc.

echo "Pascal to C"

if bounded "$phx" "$root/languages/pascal/pascal-c.phx" "$root/languages/pascal/programs/primes.pas" \
        > "$tmp0/primes.c" 2>/dev/null \
   && cc -Wall -Werror -o "$tmp0/primes" "$tmp0/primes.c" 2>/dev/null; then
    report pass "primes.pas compiles to C that cc -Werror accepts"
    # What `fpc -Miso` prints for this program, taken from fpc and kept
    # beside it. The oracle checks the two agree; this checks nothing has
    # drifted since.
    bounded "$tmp0/primes" > "$tmp0/primes.got"
    if cmp -s "$tmp0/primes.got" "$root/languages/pascal/programs/primes.expected"; then
        report pass "and the program is right"
    else
        report fail "and the program is right" "got: $got"
    fi
else
    report fail "primes.pas compiles to C that cc -Werror accepts"
fi

# gcd.pas is the fixture that has been in this repository since the first
# commit, written for another tool years before Phoenix existed. Compiling it
# is the strongest thing the Pascal description can be asked to do.
if bounded "$phx" "$root/languages/pascal/pascal-c.phx" "$root/languages/pascal/tests/grammar/gcd.pas" \
        > "$tmp0/gcd.c" 2>/dev/null \
   && cc -Wall -Werror -o "$tmp0/gcd" "$tmp0/gcd.c" 2>/dev/null; then
    report pass "gcd.pas compiles to C that cc -Werror accepts"
    bounded "$tmp0/gcd" > "$tmp0/gcd.got"
    if cmp -s "$tmp0/gcd.got" "$root/languages/pascal/tests/grammar/gcd.expected"; then
        report pass "and every line of it is right"
    else
        report fail "and every line of it is right" \
                    "$(printf '%s' "$got" | head -2 | tr '\n' '|')"
    fi
else
    report fail "gcd.pas compiles to C that cc -Werror accepts"
fi

if bounded "$phx" "$root/languages/pascal/pascal-c.phx" -o "$tmp0/pasc.c" 2>/dev/null \
   && cc -o "$tmp0/pasc" "$tmp0/pasc.c" 2>/dev/null; then
    bounded "$tmp0/pasc" "$root/languages/pascal/programs/primes.pas" > "$tmp0/again.c" 2>/dev/null
    if cmp -s "$tmp0/again.c" "$tmp0/primes.c"; then
        report pass "a standalone Pascal-to-C compiler, agreeing with phx"
    else
        report fail "a standalone Pascal-to-C compiler, agreeing with phx"
    fi
else
    report fail "a standalone Pascal-to-C compiler, agreeing with phx" "it did not build"
fi

echo "Pascal, with actions"
accepts "the description reads" "$root/languages/pascal/pascal.phx"
accepts "the outline description reads" "$root/languages/pascal/pascal-outline.phx"

# Two real Pascal programs, checked. A checker that invents an error on a
# correct program is the worst thing it could do, so this comes first.
for f in gcd features; do
    accepts "$f.pas checks clean" --driver check \
            "$root/languages/pascal/pascal-outline.phx" "$root/languages/pascal/tests/grammar/$f.pas"
done

# And one that is wrong in four ways, each of which has to be found.
errs=$(bounded "$phx" --driver check "$root/languages/pascal/pascal-outline.phx" \
        "$root/languages/pascal/tests/grammar/type-errors.pas" 2>&1)
found=0
printf '%s' "$errs" | grep -qF "cannot assign integer to boolean" && found=$((found+1))
printf '%s' "$errs" | grep -qF "'nope' is not declared"           && found=$((found+1))
printf '%s' "$errs" | grep -qF "an if wants a boolean"            && found=$((found+1))
printf '%s' "$errs" | grep -qF "a while wants a boolean"          && found=$((found+1))
if [ "$found" -eq 4 ]; then
    report pass "four Pascal mistakes, all four found"
else
    report fail "four Pascal mistakes, all four found" "found $found of 4"
fi

# `with origin do ... x ...` brings a record's fields into scope, which means
# following `origin` to its type, that type to its declaration, and that to its
# fields -- three hops through nodes the walk has already finished with. The
# test is that a real field passes and an invented one does not.
errs=$(bounded "$phx" --driver check "$root/languages/pascal/pascal.phx" \
        "$root/languages/pascal/tests/grammar/with-fields.pas" 2>&1)
if printf '%s' "$errs" | grep -qF "'zzz' is not declared" \
   && ! printf '%s' "$errs" | grep -qE "'[xy]' is not declared"; then
    report pass "a record's fields, through a with"
else
    report fail "a record's fields, through a with" \
                "$(printf '%s' "$errs" | head -1)"
fi

# `function Area;` repeating a forward heading: its parameters come from the
# declaration it repeats, which is earlier in the same list.
sed 's/Area := Pi \* r \* r/Area := Pi * rr * r/' \
    "$root/languages/pascal/tests/grammar/features.pas" > "$tmp0/fwd.pas"
errs=$(bounded "$phx" --driver check "$root/languages/pascal/pascal.phx" "$tmp0/fwd.pas" 2>&1)
if printf '%s' "$errs" | grep -qF "'rr' is not declared" \
   && ! printf '%s' "$errs" | grep -qF "'r' is not declared"; then
    report pass "a forward heading's parameters"
else
    report fail "a forward heading's parameters" "$(printf '%s' "$errs" | head -1)"
fi

for f in gcd features; do
    accepts "$f.pas builds a tree" --tree "$root/languages/pascal/pascal.phx" \
            "$root/languages/pascal/tests/grammar/$f.pas"
done
for f in keyword missing-semicolon unclosed; do
    refuses "$f.pas is still refused" "error" --tree \
            "$root/languages/pascal/pascal.phx" "$root/languages/pascal/tests/grammar/$f.pas"
done

# The tree has to be abstract, not a parse tree wearing node names: no
# punctuation, and no wrapper node holding nothing.
tree=$(bounded "$phx" --tree "$root/languages/pascal/pascal.phx" "$root/languages/pascal/tests/grammar/gcd.pas" 2>/dev/null)
if printf '%s' "$tree" | grep -qE '"[,;()]"'; then
    report fail "the Pascal tree drops its punctuation" \
                "$(printf '%s' "$tree" | grep -oE '"[,;()]"' | head -1) is in it"
else
    report pass "the Pascal tree drops its punctuation"
fi

# A pass over the whole of it, reading something from most of it.
out=$(bounded "$phx" "$root/languages/pascal/pascal-outline.phx" "$root/languages/pascal/tests/grammar/features.pas" 2>/dev/null)
if printf '%s' "$out" | grep -qF "type      Str = packed array [1..80] of char" \
   && printf '%s' "$out" | grep -qF "procedure Walk(t : Tree; var count : integer)"; then
    report pass "the outline pass reads the whole tree"
else
    report fail "the outline pass reads the whole tree" \
                "$(printf '%s' "$out" | head -2 | tr '\n' ' ')"
fi

# `var` on a parameter is matched with `Param(byref: true)`, which needs a
# boolean in a pattern to be a value rather than a name that binds anything.
if printf '%s' "$out" | grep -qF "var count : integer" \
   && ! printf '%s' "$out" | grep -q "truecount"; then
    report pass "a boolean in a pattern is a value"
else
    report fail "a boolean in a pattern is a value"
fi

# Wirth's Pascal, vendored into languages/pascal/tests/grammar -- the strongest evidence that
# this reads a real published grammar and not only its own examples. Both files
# it accepts are accepted by `fpc -Miso`. See tests/pascal/README.md for why
# these are copies.
S="$root/languages/pascal/tests/grammar"
if [ -d "$S" ]; then
    # ---------------------------------------------------------------------------
# The notation, described in itself. A notation that can describe its own
# grammar has demonstrably got enough in it; one that cannot has a hole
# somewhere it did not know about.

# An attribute is a token: `.val` is one and `. ` cannot be one. That settles
# the terminator, and it settles a case the old adjacency rule did not quite --
# `at(xs, 2).show` is an attribute of a call, with no reference before the dot.
got=$(bounded "$phx" "$root/tests/grammars/attributes.phx" \
        "$root/tests/sources/two-numbers.txt" 2>/dev/null)
if [ "$got" = "3 4" ]; then
    report pass "an attribute of a reference, of a call, and a terminator"
else
    report fail "an attribute of a reference, of a call, and a terminator" "got: $got"
fi

# Deeply nested input used to exhaust the C stack and die with a signal.
# Recursive descent makes the stack proportional to how deeply the *input*
# nests, and input is not a thing a compiler gets to trust.
awk -v n=5000 -v shape=nest -f "$root/bench/generate.awk" > "$tmp0/deep.pas"
out=$(bounded "$phx" --quiet --tree "$root/languages/pascal/pascal.phx" "$tmp0/deep.pas" 2>&1)
code=$?
if [ "$code" -ge 128 ]; then
    report fail "deep nesting is refused, not fatal" "died with signal $((code - 128))"
elif printf '%s' "$out" | grep -qF "nested too deeply"; then
    report pass "deep nesting is refused, not fatal"
else
    report fail "deep nesting is refused, not fatal" "$(printf '%s' "$out" | head -1)"
fi

echo "the notation, in itself"
accepts "phoenix.phx reads" "$root/languages/phx/phoenix.phx"

if bounded "$phx" --quiet --tree "$root/languages/phx/phoenix.phx" \
        "$root/languages/phx/phoenix.phx" >/dev/null 2>&1; then
    report pass "and parses itself"
else
    report fail "and parses itself"
fi

# Every description in the repository, read by the description of them.
bad=0
for d in "$root"/lib/*.phx "$root"/languages/*/*.phx; do
    bounded "$phx" --quiet --tree "$root/languages/phx/phoenix.phx" "$d" >/dev/null 2>&1 \
        || bad=$((bad + 1))
done
if [ "$bad" -eq 0 ]; then
    report pass "and every other description here"
else
    report fail "and every other description here" "$bad did not parse"
fi

echo "Wirth's Pascal"
    accepts "the grammar itself" "$S/pascal.bnf"
    accepts "gcd.pas"            "$S/pascal.bnf" "$S/gcd.pas"
    accepts "features.pas"       "$S/pascal.bnf" "$S/features.pas"
    refuses "keyword.pas"           "error" "$S/pascal.bnf" "$S/keyword.pas"
    refuses "missing-semicolon.pas" "error" "$S/pascal.bnf" "$S/missing-semicolon.pas"
    refuses "unclosed.pas"          "error" "$S/pascal.bnf" "$S/unclosed.pas"
    refuses "lexical.pas"           "nothing here matches" "$S/pascal.bnf" "$S/lexical.pas"

    # Both stray characters, not just the first.
    n=$(bounded "$phx" --quiet "$S/pascal.bnf" "$S/lexical.pas" 2>&1 | grep -c "nothing here matches")
    if [ "$n" -eq 2 ]; then
        report pass "both stray characters reported"
    else
        report fail "both stray characters reported" "got $n messages, wanted 2"
    fi
fi

# ---------------------------------------------------------------------------
# The oracle. Every program in languages/pascal/tests/oracle is compiled by `fpc -Miso` and by
# Phoenix, and the two must write the same bytes. fpc has been read by more
# people than this repository has, so where they differ Phoenix is wrong until
# somebody shows otherwise.
#
# Skipped and not failed without fpc: it is an oracle, not a dependency.

# Everything outside the subset has to be refused with a message, rather than
# compiled into something that runs and is wrong. See tests/refused/README.md.
echo "outside the subset"
for src in "$root"/languages/pascal/tests/refused/*.pas; do
    name=$(basename "$src" .pas)
    out=$(bounded "$phx" --driver c "$root/languages/pascal/pascal-c.phx" "$src" 2>&1 >/dev/null)
    code=$?
    if [ "$code" -eq 0 ]; then
        report fail "$name is refused" "it compiled"
    elif printf '%s' "$out" | grep -q "$(basename "$src"):[0-9]*:[0-9]*: error:"; then
        # Refused *and* pointing into the Pascal. A message about a missing
        # attribute in the description is a true sentence and no use at all to
        # somebody holding a Pascal program, so it counts as a failure.
        report pass "$name is refused, at a position in the Pascal"
    else
        report fail "$name is refused" "$(printf '%s' "$out" | head -1)"
    fi
done

echo "the oracle"
if command -v fpc >/dev/null 2>&1; then
    if oracle=$(harness "$root/languages/pascal/tests/oracle/run.sh" 2>&1); then
        n=$(printf '%s' "$oracle" | grep -c '^  ok')
        report pass "$n Pascal programs agree with fpc -Miso"
    else
        report fail "Pascal programs agree with fpc -Miso"
        printf '%s\n' "$oracle" | grep -A6 'FAIL' | sed 's/^/        /' | head -14
    fi
else
    absent=$((absent + 1))
    skip 1 "the oracle needs fpc, which is not on this machine"
fi

# Solveig's conformance suite: programs and the output each must produce, held
# against `solas` and `solvm`. A suite for the *language* rather than for one
# implementation of it -- see languages/solveig/README.md.
echo "Solveig"
accepts "the description reads" "$root/languages/solveig/solveig.phx"
if rt=$(harness "$root/languages/solveig/tests/roundtrip.sh" 2>&1); then
    n=$(printf '%s' "$rt" | awk '/round-trip to an identical tree/{print $1}')
    report pass "$n Solveig files parse, render, and parse to the same tree"
else
    report fail "Solveig files round-trip" "$(printf '%s' "$rt" | grep -v '^[0-9]' | head -2 | tr '\n' ' ')"
fi

echo "Solveig conformance"
sol=${SOLVEIG:-$root/../Solveig}
if [ -x "$sol/bin/solas" ]; then
    if conf=$(harness "$root/languages/solveig/tests/conformance/run.sh" 2>&1); then
        n=$(printf '%s' "$conf" | grep -c '^  ok')
        report pass "$n Solveig programs conform"
    else
        report fail "Solveig programs conform"
        printf '%s\n' "$conf" | grep -A6 FAIL | sed 's/^/        /' | head -12
    fi
    if bc=$(harness "$root/languages/solveig/tests/bytecode.sh" 2>&1); then
        printf '%s\n' "$bc" | grep -E '^[0-9]+ programs|^  and [0-9]+ trace' \
            | while IFS= read -r line; do
                  printf '  ok    %s\n' "$(printf '%s' "$line" | sed 's/^  and /and /')"
              done
        pass=$((pass + 2))
    else
        report fail "the .sob backend agrees with solas"
        printf '%s\n' "$bc" | sed 's/^/        /' | head -14
    fi
else
    absent=$((absent + 1))
    skip 3 "the conformance suite needs Solveig, which is not here"
fi

# Pascal units, which is an experiment rather than a language anybody wants
# compiled: does resolution here need a scope graph? `fpc -Mtp` is the arbiter,
# and it sees real separate units because the runner splits the file back into
# them. languages/units/README.md has the answer.
echo "Pascal units"
accepts "the description reads" "$root/languages/units/units.phx"
if un=$(harness "$root/languages/units/tests/run.sh" 2>&1); then
    n=$(printf '%s' "$un" | grep -c '^  ok')
    report pass "$n checks, and the two divergences are still the ones written down"
else
    report fail "the unit experiment holds"
    printf '%s\n' "$un" | grep -A5 FAIL | sed 's/^/        /' | head -14
fi

# The two tutorials in docs/, run rather than read. Each step builds the file
# the page says to build, runs the command it shows, and checks that what came
# back appears verbatim in the page -- so a pasted output that drifts fails
# here. Reading them did not find what running them did.
echo "Tutorials"
if tut=$(harness "$root/tests/tutorials.sh" 2>&1); then
    n=$(printf '%s' "$tut" | grep -c '^  ok')
    report pass "$n steps of docs/tutorial-picture.md and docs/tutorial-assembler.md"
else
    report fail "the tutorials do what they say"
    printf '%s\n' "$tut" | grep -A6 FAIL | sed 's/^/        /' | head -14
fi

# The assembler: SolVM assembly to `.sob`, which is the *producing* half of a
# format Phoenix cannot read -- a length-prefixed binary needs the match to
# depend on a count it has just read, and the notation cannot say that. So
# `solvm --dump` is the reading half, and comparing what it prints for two
# producers of one program is the oracle. See languages/solvm/README.md.
echo "SolVM assembly"
accepts "the language reads"  "$root/languages/solvm/solvm.phx"
accepts "and the assembler"   "$root/languages/solvm/solvm-sob.phx"
if sa=$(harness "$root/languages/solvm/tests/run.sh" 2>&1); then
    n=$(printf '%s' "$sa" | grep -c '^  ok')
    report pass "$n checks: the bytes, the round trip, the refusals$(printf '%s' "$sa" | grep -q 'solas' && printf ', solas, and the tutorial')"
else
    report fail "the assembler agrees with solas"
    printf '%s\n' "$sa" | grep -A4 FAIL | sed 's/^/        /' | head -14
fi

# Z80: the second assembler, and the one written to make a mechanism
# necessary rather than to have another language. Every instruction in the
# subset has **one encoding and one length**, so the two passes solvm already
# uses are enough -- which is the point. It is the control for `jr`, whose
# length depends on a distance that depends on lengths, and which is what
# ROADMAP 2.5 has been waiting for a customer to need.
#
# The oracle is `z80asm` and the comparison is **byte for byte**. That is a
# stronger arbiter than the other languages have: Pascal and Solveig agree
# about what a program prints, which a consistently wrong translation can
# survive, and an assembler's whole output is the artefact.
echo "Z80"
accepts "the description reads" "$root/languages/z80/z80.phx"
z="$root/languages/z80/tests/refused"
refuses "a jump to a label nothing defines" "no label called 'nowhere'" \
        "$root/languages/z80/z80.phx" "$z/nowhere.z80"
refuses "one label at two addresses" "two labels have the same name" \
        "$root/languages/z80/z80.phx" "$z/twice.z80"
refuses "an immediate that does not fit its byte" "at most 255, and this is 300" \
        "$root/languages/z80/z80.phx" "$z/wide.z80"
refuses "a jr the programmer wrote that does not reach" "'far' is 130 away" \
        "$root/languages/z80/z80.phx" "$z/unreachable.z80"

# **`br` picks its own encoding, and the first walk is pinned apart from the
# rest.** `layout` has met no forward label and assumes three bytes; `relax`
# has a table with every label and decides both directions against an
# over-estimate, which is the only safe direction -- shrinking one `br` only
# pulls later addresses down, so a `br` that fits against the estimate still
# fits when everything settles. The driver runs it `until labels` settles.
# `size` is the first walk's answer and `size2` the settled one.
o="$root/languages/z80/tests/oracle"
prints "a forward br is three bytes in the first walk" "5" \
       --driver code --show size "$root/languages/z80/z80.phx" "$o/short-forward.z80"
prints "and two once it settles" "4" \
       --driver code --show size2 "$root/languages/z80/z80.phx" "$o/short-forward.z80"
# The forward jump's size is what decides whether the backward one fits, and
# one extra walk gets both. The arithmetic is in the file, countable by hand.
prints "a chain settles two bytes above the minimum in one walk" "131" \
       --driver code --show size "$root/languages/z80/z80.phx" "$o/chain.z80"
prints "and reaches it" "129" \
       --driver code --show size2 "$root/languages/z80/z80.phx" "$o/chain.z80"

# **ROADMAP 2.5, which is why the driver says `until`.** Two forward `br`s,
# where the second one shrinking in walk two is what brings the first into
# range in walk *three*. Until 2026-09-23 this was a divergence, pinned at 130,
# because `relax` ran once. Three nested `br`s want walk *four*, and get it:
# no fixed number of walks is right for every program, and the driver's
# stopping rule is the one that is.
prints "a program that needs a third walk gets one" "129" \
       --driver code --show size2 "$root/languages/z80/z80.phx" "$o/two-rounds.z80"
prints "and one that needs a fourth" "131" \
       --driver code --show size2 "$root/languages/z80/z80.phx" "$o/three-rounds.z80"
prints "which the first walk left three bytes long" "134" \
       --driver code --show size "$root/languages/z80/z80.phx" "$o/three-rounds.z80"
if command -v z80asm >/dev/null 2>&1; then
    if za=$(harness "$root/languages/z80/tests/oracle/run.sh" 2>&1); then
        n=$(printf '%s' "$za" | grep -c '^  ok')
        report pass "$n Z80 programs assemble to the bytes z80asm makes, exactly"
    else
        report fail "Z80 programs agree with z80asm"
        printf '%s\n' "$za" | grep -A3 FAIL | sed 's/^/        /' | head -12
    fi
else
    absent=$((absent + 1))
    skip 1 "the oracle needs z80asm, which is not on this machine"
fi

# awk: the third language, and the first whose grammar is not vendored -- there
# is no awk grammar on this machine to hold it against, so the oracle carries
# the whole weight. `/usr/bin/awk` is the arbiter of what awk means, and
# `corpus/` is awk that e2fsprogs, ncurses and vim ship.
echo "awk"
accepts "the description reads" "$root/languages/awk/awk.phx"
if rt=$(harness "$root/languages/awk/tests/roundtrip.sh" 2>&1); then
    report pass "$(printf '%s' "$rt" | tail -1)"
else
    report fail "awk programs round-trip"
    printf '%s\n' "$rt" | sed 's/^/        /' | head -8
fi
# **Two places this description reads awk differently from awk**, both of them
# the lexical seam that `docs/ROADMAP.md` 3.3 says Phoenix will not guess at.
# They are pinned here so that they are named rather than found: a change to
# either shows up as a failing test with the old answer in it.
d="$root/languages/awk/tests/divergent"
prints "a/b/c is read as a regexp between two names" \
       "BEGIN { print a /b/ c }" "$root/languages/awk/awk.phx" "$d/slash.awk"
prints "and f (1) as a call, where awk concatenates" \
       "BEGIN { x = f(1) }" "$root/languages/awk/awk.phx" "$d/spaced-call.awk"
# The third witness, and the one found by writing a program rather than by
# thinking about it: a regexp may not begin with a space either.
#
# **This expectation used to be `and found "BEGIN"`**, which was the parser
# blaming the first token of the file for a fault 34 columns into line 13. It
# was not asserting the divergence; it was pinning a defect in `parse_run`,
# which reported the first leftover token and the wants from somewhere else.
# What the refusal is *about* is the position, so that is what is checked.
refuses "a regexp beginning with a space" "spaced-regex.awk:13:34" \
        "$root/languages/awk/awk.phx" "$d/spaced-regex.awk"

# **A call is resolved over the whole program**, so a function may be used
# above where it is defined -- which is the forward reference ROADMAP 2.1 is
# about, and which two passes answer: one collects what functions there are,
# the other hands the table down and checks the calls. What awk finds when the
# call runs, this finds while reading the program.
a="$root/languages/awk/awk.phx"
accepted=0; rejected=0
for f in "$root"/languages/awk/tests/corpus/*.awk \
         "$root"/languages/awk/tests/conformance/*.awk; do
    if bounded "$phx" --quiet --driver check "$a" "$f" >/dev/null 2>&1
    then accepted=$((accepted+1))
    else rejected=$((rejected+1)); echo "  check refuses $(basename "$f")"
         bounded "$phx" --quiet --driver check "$a" "$f" 2>&1 | head -2 | sed 's/^/      /'
    fi
done
if [ "$rejected" -eq 0 ]; then
    report pass "$accepted awk programs pass the call check"
else
    report fail "awk programs pass the call check" "$rejected refused"
fi

refuses "a call to a function nothing defines" "is not a function in this program" \
        --driver check "$a" "$root/languages/awk/tests/refused/undefined-function.awk"
refuses "a call with more arguments than parameters" "and this gives 2" \
        --driver check "$a" "$root/languages/awk/tests/refused/too-many-arguments.awk"
# And the one the whole exercise is for: defined *below* the call, and fine.
accepts "a function called above where it is defined" \
        --driver check "$a" "$root/languages/awk/tests/conformance/functions.awk"

if orc=$(harness "$root/languages/awk/tests/oracle.sh" 2>&1); then
    report pass "$(printf '%s' "$orc" | tail -1)"
else
    report fail "rendered awk does the same thing"
    printf '%s\n' "$orc" | sed 's/^/        /' | head -12
fi

# The conformance rule with a third language under it: awk compiled to C, run,
# and compared with what `/usr/bin/awk` prints on the same input.
if be=$(harness "$root/languages/awk/tests/backend/run.sh" 2>&1); then
    report pass "$(printf '%s' "$be" | tail -1)"
else
    report fail "awk compiled to C prints what awk prints"
    printf '%s\n' "$be" | sed 's/^/        /' | head -12
fi

# The backend is a subset, and what is outside it is refused **by name** rather
# than mis-compiled. All three of these are valid awk.
c="$root/languages/awk/awk-c.phx"
t="$root/languages/awk/tests/not-yet"
# `getline` is described and not compiled -- described because without a rule
# mentioning the word, `getline line` reads as two variables concatenated,
# which is a silent mis-parse of ordinary awk.
refuses "getline, which is read and not compiled" "getline is not compiled" \
        --driver c "$c" "$t/getline.awk"
refuses "and the piped form, which needed a rung of its own to read" \
        "getline is not compiled" --driver c "$c" "$t/getline-pipe.awk"

# C: the language ROADMAP 6 puts on the page as a goal rather than a mechanism.
# The first seven constructs, `int main(){return 42;}`, `+ - * /` with
# parentheses, unary minus with the comparisons, a local `int`, `if`, `while`,
# `for` and blocks, functions with parameters and calls, `&` and `*` with
# the pointer declarators, `sizeof`, and an array that decays to a pointer to
# its first element, emitted as arm64 assembly that `cc` assembles and
# links. The oracle is `cc` itself, and what is compared is what a program
# exits with, because until a function can be called that is all a program
# can say. Skipped where the machine is not arm64, since `cc`
# there assembles something else.
echo "C"
accepts "the description reads" "$root/languages/c/c-arm64.phx"
# What the subset refuses, by name and with a position: the `locals` pass is
# the first thing in this language that can say no.
r="$root/languages/c/tests/refused"
refuses "a name nothing declared" "'x' is not declared" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/undeclared.c"
refuses "and one assigned before it is declared" "'y' is not declared" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/assign-undeclared.c"
refuses "a name declared twice in one scope" "'x' is declared twice" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/twice.c"
refuses "and one read after its block has closed" "'y' is not declared" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/out-of-scope.c"
refuses "a parameter declared again in the body" "'a' is declared twice" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/param-redeclared.c"
# C99 6.5.2.2 wants a declaration above every call, so what awk answered with
# a gathered table C answers with a thread, and a prototype is how a call
# reaches a function below it.
refuses "a call to nothing" "'f' is called before it is declared" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/undefined-function.c"
refuses "a call above the definition, with no prototype" \
        "'twice' is called before it is declared" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/forward-call.c"
refuses "a call with the wrong number of arguments" "takes 2 arguments, and this gives 1" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/wrong-arity.c"
refuses "a function defined twice" "a function is defined twice" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/defined-twice.c"
refuses "a prototype and a definition that disagree" "two different numbers of parameters" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/two-arities.c"
refuses "a ninth parameter, which is outside the subset" "only eight are compiled" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/nine-params.c"
# What `&` and `*` add to the list. The first two are the grammar's, because a
# place is a rule and not a pass: C11 6.5.3.2 wants an lvalue after `&` and
# 6.5.16 wants one before `=`, and a rule that only matches those two is that
# constraint at no cost. The rest are the `types` pass, which knows how many
# stars a value has and nothing else about its type.
#
# The message for `&1` names what may follow the `1`, and has moved four
# times. A subscript was the first way a number becomes the start of a place,
# `&1[a]` being `&(1[a])`, and a member is the second, since `struct`: `&1.x`
# is a place the `types` pass refuses rather than the grammar. A postfix `++`
# and `--` are the third, since 2026-09-25, as suffixes in the same fold. So
# the refusal is only certain at the token after the `1`, and names all five.
# `address-of-a-subscripted-number` in the oracle is the program that makes
# the message true.
refuses "the address of something that is not a place" 'expected [, ., ->, ++, -- or (, and found ";"' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/address-of-a-number.c"
refuses "and an assignment to one" 'and found "="' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/assign-to-a-number.c"
refuses "a '*' on an int" "'*' wants a pointer" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/deref-an-int.c"
refuses "and on a name nothing declared" "'p' is not declared" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/deref-undeclared.c"
refuses "a '-' on a pointer" "'-' wants a number" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/negate-a-pointer.c"
refuses "a '*' between a pointer and a number" "'*' does not take a pointer" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/multiply-a-pointer.c"
# `%` wants integers on both sides, C11 6.5.5, since 2026-09-25 (ROADMAP 6.3).
# `cc` refuses both, at the same column.
refuses "a '%' of a pointer" "'%' does not take a pointer" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/remainder-of-a-pointer.c"
refuses "and of a struct" "'%' wants numbers, and this is 'struct t'" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/remainder-of-a-struct.c"
# `!`, `&&` and `||` test what they are given as a condition does, so a struct
# is refused in each, as `cc` refuses it, at the same column.
refuses "a '!' of a struct" "'!' tests a number or a pointer, and this is 'struct t'" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/not-a-struct.c"
refuses "a struct on the left of '&&'" "'&&' tests numbers and pointers, and this is 'struct t'" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/and-a-struct.c"
refuses "and on the right of '||'" "'||' tests numbers and pointers, and this is 'struct t'" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/or-a-struct.c"
# `++`, `--` and the compound assignments, since 2026-09-25: an update takes
# what `=` takes and what its operator takes, both. Every one below `cc`
# refuses too. `3 += x` is a syntax error here, as `3 = x` is, and
# `(x = 2)++` gets past the grammar, since a postfix `++` is a suffix like
# `[ ]`, and is refused by the `types` pass, where `lvalue` is.
refuses "a '++' on an array" "'++' is given an array" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/increment-an-array.c"
refuses "a '+=' to a struct" "'+=' wants a number or a pointer, and this is 'struct t'" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/add-to-a-struct.c"
refuses "and of one" "'+=' wants a number on its right, and this is 'struct t'" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/add-a-struct.c"
refuses "a pointer added to an int in place" "'+=' does not take a pointer on its right" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/add-a-pointer-to-an-int.c"
refuses "and to a pointer" "'+=' does not take a pointer on its right" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/add-a-pointer-to-a-pointer.c"
refuses "a pointer multiplied in place" "'*=' does not take a pointer" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/multiply-a-pointer-in-place.c"
refuses "a '+=' to a number" 'and found "+="' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/add-to-a-number.c"
refuses "a '++' on an assignment" "'++' wants somewhere a value is kept" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/increment-an-assignment.c"
# The bitwise operators, the shifts, `~`, unary `+` and `?:`, since 2026-09-25.
# The first nine `cc` refuses too.
refuses "a '~' of a pointer" "'~' wants a number, and this is a pointer" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/invert-a-pointer.c"
refuses "a '+' of a pointer" "'+' wants a number, and this is a pointer" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/plus-a-pointer.c"
refuses "a pointer shifted" "'<<' does not take a pointer" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/shift-a-pointer.c"
refuses "a pointer and-ed" "'&' does not take a pointer" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/and-a-pointer.c"
refuses "a struct or-ed" "'|' wants numbers, and this is 'struct t'" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/or-a-struct-bitwise.c"
refuses "a struct as the choice" "'struct t' is a condition" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-as-a-choice.c"
refuses "a struct on one side of '?:' only" "'?:' has a struct on one side and not on the other" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/choose-a-struct-or-a-number.c"
refuses "two kinds of struct" "'?:' has 'struct t' on one side and 'struct u' on the other" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/choose-two-structs.c"
refuses "a pointer shifted in place" "'<<=' does not take a pointer" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/shift-a-pointer-in-place.c"
# These two `cc` compiles, and this subset declines by name: a pointer beside
# `0` needs a null pointer constant, a literal 0 known from any other `int`,
# and two kinds of pointer have no one type for the answer. `cc` only warns.
refuses "a pointer or 0" "this subset has no null pointer constant" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/choose-a-pointer-or-zero.c"
refuses "pointers to two types" "'?:' has pointers to two different types" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/choose-two-pointers.c"
# `break` and `continue` belong to a loop, since 2026-09-25 (ROADMAP 6.4):
# outside every loop, or after one has ended, each is refused, as `cc`
# refuses it, at the same column.
refuses "a 'break' outside a loop" "'break' is not inside a loop" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/break-outside-a-loop.c"
refuses "a 'continue' outside a loop" "'continue' is not inside a loop" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/continue-outside-a-loop.c"
refuses "a 'break' after a loop has ended" "'break' is not inside a loop" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/break-after-a-loop.c"
# A label belongs to its function, anywhere in it: a `goto` to a label no
# statement has, or one another function has, is refused, and so is one label
# twice. `cc` refuses all three.
refuses "a 'goto' to no label" "there is no label 'nowhere' in this function to go to" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/goto-nowhere.c"
refuses "a 'goto' to another function's label" "there is no label 'here' in this function to go to" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/goto-another-functions-label.c"
refuses "a label twice" "the label 'here' is in this function twice" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/label-twice.c"
# `switch`, `case` and `default`, since 2026-09-25 (ROADMAP 6.4 and 6.5). A
# `case` label is worked out before the program runs, by the `constants` pass,
# and the first nine below `cc` refuses too. `duplicate-case` is `sizeof(long)`
# beside `1 << 3`, and only a compiler that knows both values can see it.
refuses "a 'case' outside a switch" "'case' is not inside a switch" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-outside-a-switch.c"
refuses "a 'default' outside a switch" "'default' is not inside a switch" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/default-outside-a-switch.c"
refuses "two 'default's" "this switch has a 'default' already" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/default-twice.c"
refuses "a 'continue' in a switch in no loop" "'continue' is not inside a loop" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/continue-in-a-switch.c"
refuses "a switch on a pointer" "'switch' wants an integer, and this is a pointer" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/switch-on-a-pointer.c"
refuses "and on a struct" "'switch' wants an integer, and this is 'struct t'" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/switch-on-a-struct.c"
refuses "a 'case' label that is a variable" "a 'case' label has to be worked out before the program runs, and this one cannot be" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-not-constant.c"
refuses "one divided by zero" "a 'case' label has to be worked out before the program runs, and this one cannot be" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-divided-by-zero.c"
refuses "two 'case's with one value" "'case 8' is in this switch twice" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/duplicate-case.c"
# Two `cc` compiles, and this subset declines by name. C11 6.6p3 says a
# constant expression has no comma, and clang takes one as an extension; and a
# label too wide for an `int` switch, which `cc` converts and warns about.
refuses "a comma in a 'case' label" "a 'case' label has to be worked out before the program runs, and this one cannot be" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-with-a-comma.c"
refuses "a label wider than the switch" "'case 4294967296' is wider than the int this switch compares" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-wider-than-the-switch.c"
# Pointer arithmetic, C11 6.5.6. A pointer and a number go either way round
# for `+` and pointer first for `-`, and two pointers may be subtracted when
# they point at the same type. All three refused here `cc` refuses too.
refuses "a '+' of two pointers" "'+' does not add two pointers" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/add-two-pointers.c"
refuses "a pointer taken from a number" "'-' does not take a pointer from a number" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/number-minus-a-pointer.c"
refuses "a difference of two pointers to different types" \
        "only when they point at the same type" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/subtract-unlike-pointers.c"
# The same type means the same stars **and** the same thing under them, since
# `char`: a type is two numbers now, and both have to agree.
refuses "and a 'char *' less an 'int *'" "only when they point at the same type" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/subtract-char-from-int-pointer.c"
# Character constants are printable ASCII or one of six escapes, and the lexer
# says so, which is what lets the `types` pass find every code in its table.
# All three below are C, and `cc` compiles them; they are refused here as
# outside the subset, at the quote, by the lexer.
refuses "a hex escape in a character constant" "nothing here matches any token rule" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/char-constant-hex-escape.c"
refuses "two characters in one" "nothing here matches any token rule" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/char-constant-two-characters.c"
refuses "and a tab typed between the quotes" "nothing here matches any token rule" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/char-constant-a-tab.c"
# A string literal takes five of those escapes and not `\0`, because C reads
# up to three octal digits after it and a lexer that knew only `\0` would
# miscount `"\01"`. Two literals side by side, which C joins, reach the parser
# as two strings and are a syntax error at the second. `cc` compiles both.
refuses "a NUL written into a string" "nothing here matches any token rule" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/string-with-a-nul.c"
refuses "and two strings side by side" 'and found ""b""' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/string-concatenated.c"
# A subscript is a `*` of a `+`, C11 6.5.2.1, and builds nothing else, so an
# `int` subscripted is refused as the `*` it is. `cc` says *subscripted value*;
# the program is refused either way, and the message names the operator the
# standard defines a subscript as.
refuses "a subscript on an int" "'*' wants a pointer" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/index-an-int.c"
# `sizeof` does not evaluate its operand, and the passes walk it anyway, which
# is C: the name still has to be declared and the call still has to have the
# right number of arguments.
refuses "a 'sizeof' of a name nothing declared" "'y' is not declared" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/sizeof-undeclared.c"
refuses "and a '*' on what a 'sizeof' is worth" "'*' wants a pointer" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/deref-a-sizeof.c"
# An array decays to a pointer, so there is nothing left to assign to, which
# `cc` says too. The other is refused where `cc` compiles: a zero-length
# array is a C11 6.7.6.2 violation this `cc` takes as an extension, and
# refusing it is what keeps a count of zero free to mean *not an array*
# everywhere else.
refuses "an assignment to an array" "an array is not something a value can be put in" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/assign-to-an-array.c"
refuses "an array of no elements" "C11 6.7.6.2 forbids" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/array-of-no-elements.c"
# `struct`. A tag is defined once in a scope, with at least one member,
# none of them twice and none of them the struct itself; `cc` refuses all of
# those but the empty struct, which it takes as an extension with a size of
# 0, and which is refused here as `int a[0]` is. An object of a struct that
# is not complete where it is declared is refused, as `cc` refuses it.
#
# Until ROADMAP 6.12's third part a struct was defined at file scope only
# and always with a tag, and a pointer to one nobody defined was refused;
# all three programs are in the oracle now.
refuses "a struct nobody defined" "'x' is declared of 'struct nope', which is not complete here, C11 6.7p7" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-undefined.c"
refuses "a struct defined twice" "'struct t' is defined twice" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-defined-twice.c"
refuses "a member declared twice" "'a' is a member twice" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-member-twice.c"
refuses "a struct with no members" "C11 6.7.2.1 forbids" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-no-members.c"
refuses "a member array of no elements" "C11 6.7.6.2 forbids" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-member-array-of-no-elements.c"
refuses "a struct that contains itself" "cannot be a member of itself" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-contains-itself.c"
# A member asked of the wrong thing. `->` is built as `(*p).x`, so a `->` on
# a struct is refused by the `*`, and on a pointer to a pointer by the `.`.
refuses "a member the struct does not have" "'struct t' has no member 'b'" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-no-such-member.c"
refuses "a member of an int" "'a' is asked for as a member of something that is not a struct" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/member-of-an-int.c"
refuses "a '->' on a struct" "'*' wants a pointer, and this is a struct" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/arrow-on-a-struct.c"
refuses "and on a pointer to a pointer" "is asked for as a member of something that is not a struct" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/arrow-on-a-pointer-to-a-pointer.c"
refuses "a difference of pointers to two structs" "only when they point at the same type" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/subtract-pointers-to-unlike-structs.c"
# **A struct is copied whole**, since 2026-09-23, by `=`, by an initialiser
# and as an argument, and the three programs that were refused for it are
# oracle programs now. What C still refuses is a copy between two kinds of
# struct, or between a struct and anything else, because no length is right
# for it; each is refused here with the pair it was given.
refuses "a struct assigned another kind" "'struct t' is assigned 'struct u'" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-assigned-another-kind.c"
refuses "a struct assigned a number" "is assigned something that is not a struct" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-assigned-a-number.c"
refuses "a struct initialised from another kind" "initialised from a 'struct u'" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-initialised-from-another-kind.c"
refuses "a struct passed to an int parameter" "'f' is given a struct where its parameter is not that struct" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-argument.c"
refuses "to a parameter of another kind" "'f' is given a struct where its parameter is not that struct" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-argument-of-another-kind.c"
refuses "a number passed to a struct parameter" "something else where its parameter is a struct" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-parameter-given-a-number.c"
refuses "a parameter declared as two structs" "a parameter that is a struct in one is not the same struct in the other" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-parameter-declared-two-ways.c"
# A struct of nine to sixteen bytes takes two registers, so seven `int`s and
# one of those is nine, and the ninth is the stack, which nothing here writes.
# `cc` compiles it; this is outside the subset, as a ninth `int` is.
refuses "a struct parameter that needs a ninth register" "needs a ninth register" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-parameter-needs-a-ninth-register.c"
# **A struct where C wants a number.** Each of these compiled, until
# 2026-09-23, into the struct's address used as a number, which is what a
# struct is worth in the emit pass; `cc` refuses every one. Found while
# writing the copy, which is the first thing to move struct values around.
refuses "a struct put in an int" "'struct t' is put where a number or a pointer goes" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-put-in-an-int.c"
refuses "a struct initialising a pointer" "'struct t' is put where a number or a pointer goes" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-initialises-a-pointer.c"
refuses "a struct returned" "'struct t' is returned" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-returned.c"
refuses "a struct as a condition" "'struct t' is a condition" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-as-a-condition.c"
refuses "and as a for's condition" "a struct is a condition" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-as-a-for-condition.c"
refuses "a struct added" "'+' wants numbers or pointers, and this is 'struct t'" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-added.c"
refuses "a struct multiplied" "'*' wants numbers, and this is 'struct t'" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-multiplied.c"
refuses "a struct compared" "'==' compares numbers and pointers" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-compared.c"
# C11 6.5.16: an assignment is a value and not somewhere a value is kept, so a
# member of one can be read and not written or pointed at. The `place` rule
# took `(x = y).a` as a place all along, and nothing could reach it until a
# struct could be the value of an expression.
refuses "a member of an assignment, assigned" "a member of an assignment or a call is a member of a value" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-member-of-an-assignment-assigned.c"
refuses "and its address taken" "'&' wants somewhere a value is kept" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-member-of-an-assignment-addressed.c"
refuses "a struct negated" "'-' wants a number, and this is 'struct t'" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-negated.c"
# `typedef`, which is what `%names` is for. A name the parse has hidden is not
# a type again until its scope ends, so `T x` after `int T` is two names in a
# row, which is a syntax error here as it is under `cc`; and the hiding ends
# with the function, which is why the third file's `T T` parses. A second
# typedef of one name is C11 6.7p3's only when it names the same type.
refuses "a typedef hidden by a local, then used as a type" 'and found "x"' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/typedef-hidden-then-used-as-a-type.c"
refuses "and one hidden by its own local, in another function" 'and found "y"' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/typedef-hidden-by-its-own-local.c"
refuses "a typedef twice, for two types" "'T' is a typedef twice, for two different types" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/typedef-twice-differently.c"
refuses "a typedef used as a value" "'T' is not declared" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/typedef-used-as-a-value.c"
# A local is in scope from the end of its declaration here, and from the end
# of its declarator in C11 6.2.1p7, so `int x = sizeof(x);` is refused where
# `cc` answers 4. That was so before `typedef`, and is written down now
# because `typedef` gave it a second form: `int T = sizeof(T);` with `T` a
# typedef of `char`. The parse reads the second `T` as the variable, because
# `%names` binds at the name, and the pass refuses it as the first. Before the
# binding moved to the name it compiled, and answered 1 where `cc` says 4.
refuses "a local in its own initialiser" "'x' is not declared" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/local-in-its-own-initialiser.c"
refuses "and a typedef hidden in its hider's initialiser" "'T' is not declared" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/typedef-hidden-in-its-own-initialiser.c"
# **A struct returned**, since 2026-09-23. A `return` is a copy into what the
# function returns, so it takes the assignment's rule: its own kind of struct,
# and no struct where the function returns an `int`. A struct a call gives back
# is a value, C11 6.5.2.2, so a member of it is read and never assigned or
# pointed at, as a member of an assignment is. All of these `cc` refuses too.
refuses "a struct returned where another is" "'struct u' is returned, and this function returns 'struct t'" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-returned-of-another-kind.c"
refuses "a number returned where a struct is" "a function that returns 'struct t' returns something that is not a struct" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-function-returns-a-number.c"
refuses "a function declared to return two types" "'f' is declared twice, returning a different type each time" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-return-declared-two-ways.c"
refuses "a struct a call returned, put in an int" "'struct t' is put where a number or a pointer goes" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-call-put-in-an-int.c"
refuses "a member of a call, assigned" "a member of an assignment or a call is a member of a value" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-member-of-a-call-assigned.c"
refuses "and its address taken" "'&' wants somewhere a value is kept" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-member-of-a-call-addressed.c"
# Two that `cc` compiles and this subset declines by name. A `char` would
# come back in a register nothing here narrows, and `main` returning a struct,
# which `cc` only warns about, exits with whatever the struct left in `w0`:
# there is no answer for the oracle to compare. A pointer was the third until
# 2026-09-25, ROADMAP 6.2, and its program is in the oracle now.
refuses "a function returning a char" "'f' returns a char" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/function-returns-a-char.c"
refuses "main returning a struct" "'main' returns an int" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/main-returns-a-struct.c"
# **`long`**, since 2026-09-23. A caller widens an `int` it passes to a `long`
# parameter, so a prototype and a definition have to agree about which
# parameters are `long`s, and about what is returned; `cc` refuses both as
# conflicting types.
refuses "a long parameter declared as an int" "a parameter that is a long in one is not in the other" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/long-parameter-declared-two-ways.c"
refuses "a long return declared as an int" "returning a different type each time" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/long-return-declared-two-ways.c"
# **A constant**, since 2026-09-27, ROADMAP 6.9's third part: hex, octal and
# the suffixes, whose programs `1L` and one past the largest `long` left this
# list for the oracle. `cc` refuses all but one of these: an octal digit of 8
# or 9, a constant too big for an `unsigned long` in each base, `0x` with no
# digits, and a suffix twice. `1ll` is `long long`'s, which is not here, and a
# syntax error at its second `l`.
refuses "an octal constant with an 8" "8 and 9 are not octal digits" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/octal-with-an-eight.c"
refuses "a decimal constant too big for any type" "is too big for any integer type" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/decimal-too-big-for-any-type.c"
# And once: the library's `int` refuses text that does not fit, and is never
# handed it, or a second complaint names a line of `c.phx` after the right
# one about the program. The check is the guard.
n=$(bounded "$phx" --driver check "$root/languages/c/c-arm64.phx" \
        "$r/decimal-too-big-for-any-type.c" 2>&1 | grep -c "error:")
if [ "$n" -eq 1 ]; then
    report pass "and says so once"
else
    report fail "and says so once" "got $n errors, wanted 1"
fi
refuses "a hex constant too big for any type" "is too big for any integer type" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/hex-too-big-for-any-type.c"
refuses "an octal constant too big for any type" "is too big for any integer type" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/octal-too-big-for-any-type.c"
refuses "0x with no digits" 'and found "x"' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/hex-with-no-digits.c"
refuses "a suffix twice" 'and found "u"' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/suffix-twice.c"
# `long long`'s suffix was refused here at its second `l` until ROADMAP
# 6.15's first part; that program is in the oracle, and the suffix with
# its letters in two cases is the refusal now.
refuses "'lL', which is no suffix" 'and found "L"' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/suffix-lL.c"
# **`unsigned`**, since 2026-09-26, ROADMAP 6.9. `cc` refuses the first
# three. The rest it compiles: a label too wide for the `unsigned int` a
# `switch` compares, which `cc` converts and this declines, as it declines
# one too wide for an `int`. A negative label in such a `switch`, and a label with a
# cast to an unsigned type, were refused until 2026-09-27, when the third
# part taught the `constants` pass to wrap; both programs are in the oracle.
refuses "unsigned beside struct" 'and found "struct"' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/unsigned-struct.c"
refuses "unsigned beside void" "'unsigned void' is not one of the types C11 6.7.2p2 lists" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/unsigned-void.c"
refuses "signed beside unsigned" "'signed unsigned' is not one of the types C11 6.7.2p2 lists" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/signed-unsigned.c"
refuses "a case too wide for an unsigned int switch" "is wider than the unsigned int this switch compares" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-wider-than-an-unsigned-switch.c"
# Two labels alike once converted to the `unsigned int` compared, which `cc`
# refuses: `-1` and `4294967295u` are one label there.
refuses "two case labels alike once converted" "'case 4294967295' is in this switch twice" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/duplicate-case-after-conversion.c"
refuses "and the other way round" "'case 4294967295' is in this switch twice" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/duplicate-case-negative-after-conversion.c"
refuses "an unsigned int label too wide for an int switch" "is wider than the int this switch compares" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-unsigned-in-an-int-switch.c"
# **`...`**, since 2026-09-26, ROADMAP 6.6. `cc` refuses all three: `...`
# with no named parameter before it, `...` anywhere but last, and a
# prototype with `...` beside a definition without. The first two are
# syntax errors here, at the token where the `)` or a parameter was wanted.
refuses "... with no parameter before it" 'and found "..."' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/ellipsis-with-no-parameter.c"
refuses "... before another parameter" 'expected ), and found ","' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/ellipsis-not-last.c"
refuses "... in a prototype and not in the definition" "with '...' in one place and without it in another" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/variadic-declared-two-ways.c"
# A call through `...` gives at least the named arguments, as `cc` says.
# A struct among the rest is refused by name, though `cc` compiles it:
# Apple's arm64 lays one out by rules of its own, and nothing reads it.
refuses "a variadic call with too few arguments" "takes at least 1 arguments, and this gives 0" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/too-few-for-a-variadic.c"
refuses "a struct passed through ..." "is given a 'struct pair' through '...'" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-through-dots.c"
# **`void`**, since 2026-09-26, ROADMAP 6.7. A `void` value is a record
# to the types pass, so it is refused wherever a struct is refused where C
# wants a number, and the message says 'void'. `cc` refuses the first nine
# as well. The last four it compiles: `main` returning `void`, and three
# GNU extensions, `sizeof(void)` as 1 and `void *` arithmetic in bytes, and
# a typedef of `void`, which is C and is not here yet.
refuses "return; from a function that returns an int" "'return;' returns nothing" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/return-nothing-from-an-int.c"
refuses "a value returned from a void function" "a function that returns 'void' returns a value" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/return-a-value-from-void.c"
refuses "a void value put in an int" "'void' is put where a number or a pointer goes" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/void-value-used.c"
refuses "a void value added to" "'+' wants numbers or pointers, and this is 'void'" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/void-value-added.c"
refuses "a void value passed" "is given the value of something 'void'" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/void-value-as-an-argument.c"
refuses "a void local" "'v' is declared 'void'" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/void-local.c"
refuses "a void parameter" "'x' is a parameter of type 'void'" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/void-parameter.c"
refuses "a void member" "'v' is a member of type 'void'" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/void-member.c"
refuses "* on a void pointer" "'*' on a 'void *' has nothing to read" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/deref-a-void-pointer.c"
refuses "main returning void" "'main' returns an int, C11 5.1.2.2.1, and this says 'void'" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/main-returns-void.c"
refuses "sizeof of void" "'sizeof' of 'void' has no size" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/sizeof-void.c"
refuses "arithmetic on a void pointer" "'+' on a 'void *' counts in something of no size" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/void-pointer-arithmetic.c"
refuses "a typedef of void" "is a typedef of 'void', which is C and is not here yet" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/typedef-of-void.c"
# **Casts**, since 2026-09-26, ROADMAP 6.7. `cc` refuses all but the third,
# a cast to a struct, which it allows as GNU C does. A cast is a value and
# not a place, and the `place` rule has no cast in it, so assigning to one
# and taking its address are syntax errors, as `f() = 3` is. Since ROADMAP
# 6.13's fourth part a type in parentheses after `&` may begin a compound
# literal, so `&(long)x` is refused at the `x`, where its `{` was wanted.
refuses "a struct cast to a number" "'struct s' is cast to something other than 'void'" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/cast-a-struct-to-a-number.c"
refuses "a void value cast to an int" "'void' is cast to something other than 'void'" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/cast-a-void-value.c"
refuses "a cast to a struct" "a cast to 'struct s' is not C" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/cast-to-a-struct.c"
refuses "an assignment to a cast" 'and found "="' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/assign-to-a-cast.c"
refuses "the address of a cast" 'expected {, and found "x"' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/address-of-a-cast.c"
refuses "a cast to void read as a value" "'void' is put where a number or a pointer goes" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/use-a-void-cast.c"
refuses "two case labels equal through a cast" "'case 44' is in this switch twice" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/duplicate-case-through-a-cast.c"
# **A `long` constant folds**, since 2026-09-26, ROADMAP 6.8, when its
# answer fits in sixty-four bits. One that does not is an overflow, which C
# leaves undefined and `cc` wraps with a warning; it is not settled here, so
# a `case` of one is refused.
# Each operator that can overflow asks first, and each asking has its own
# witness here, since one program with four labels stays refused when only
# one of the four questions is broken.
refuses "a case label that adds past a long" "and C leaves this one undefined" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-overflows-a-long.c"
refuses "a case label that subtracts past a long" "and C leaves this one undefined" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-subtracts-past-a-long.c"
refuses "a case label that divides the most negative long by -1" "and C leaves this one undefined" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-divides-the-most-negative-long.c"
refuses "a case label that shifts an int past its width" "and C leaves this one undefined" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-shifts-an-int-past-its-width.c"
# **A refusal names its reason**, since 2026-09-29. Until then every one
# said the value *cannot be* worked out, which was true of `y` and `1 / 0`
# and not of the rest: C leaves an overflow undefined, and `cc` folds it
# with a warning; and C works out an `unsigned long` past 2^63, which this
# compiler holds on purpose and does not. The first three below were
# written for ROADMAP 6.9's second part and asserted by nothing until now.
# Each unary node hands its operand's reason up, and each has a witness, as
# does each way a binary one decides. Where two operands disagree the
# stronger claim wins, tried once on each side, so that a rule reading only
# one operand is seen.
L="which C works out and this compiler does not"
refuses "sizeof less 5, which C works out" "$L" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-sizeof-below-zero.c"
refuses "~sizeof, which C works out" "$L" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-inverts-sizeof.c"
refuses "a global of -sizeof, which C works out" "'g' has to be initialised with something worked out before the program runs, C11 6.7.9p4, and this one is 'unsigned long' arithmetic past 2^63" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/global-negated-sizeof.c"
refuses "an unsigned long product past 2^64, which C wraps" "$L" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-multiplies-sizeof-past-2-64.c"
refuses "and one divided by zero, which is no constant" "and this one cannot be" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-divides-sizeof-by-zero.c"
refuses "a long shifted by 63" "shifts a 'long' by 63, which this compiler does not work out" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-shifts-a-long-by-63.c"
refuses "and by 64, which C leaves undefined" "and C leaves this one undefined" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-shifts-a-long-by-64.c"
refuses "the most negative long negated" "and C leaves this one undefined" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-negates-the-most-negative-long.c"
refuses "an overflow on the right beats sizeof on the left" "and C leaves this one undefined" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-undefined-beside-sizeof.c"
refuses "a variable on the left beats sizeof on the right" "and this one cannot be" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-variable-beside-sizeof.c"
refuses "a comparison hands its operand's reason up" "and C leaves this one undefined" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-compares-an-overflow.c"
refuses "and so does '&&', from its left" "$L" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-and-of-sizeof-below-zero.c"
refuses "and '||', from its right" "$L" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-or-of-sizeof-below-zero.c"
refuses "and '?:' its condition's" "$L" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-chooses-on-sizeof-below-zero.c"
refuses "and the side it picks, the first" "$L" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-picks-sizeof-below-zero.c"
refuses "and the second" "$L" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-chooses-sizeof-below-zero.c"
refuses "and '!'" "$L" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-not-of-sizeof-below-zero.c"
refuses "and unary '+'" "$L" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-plus-of-sizeof-below-zero.c"
refuses "and a cast" "$L" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-casts-sizeof-below-zero.c"
# `cc` takes this one as it takes a comma, though C11 6.6p6 lets an integer
# constant expression cast only to arithmetic types.
refuses "a cast through a pointer" "and this one cannot be" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/case-casts-to-a-pointer.c"
# **Globals**, since 2026-09-26, ROADMAP 6.8. `cc` refuses the first ten.
# The last three it compiles: a global declared twice where one has no
# initialiser, C11 6.9.2's tentative definition, both ways round, which is
# what a common symbol is for; and an array of no elements, as for a local.
refuses "a global defined twice" "'x' is defined twice, with an initialiser each" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/global-defined-twice.c"
refuses "a global, then a function of its name" "'f' is a global already" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/global-then-function.c"
refuses "a function, then a global of its name" "'f' is a function already" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/function-then-global.c"
refuses "a global named like a typedef" "'t' is a typedef already" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/global-named-like-a-typedef.c"
refuses "a typedef named like a global" "'t' is a global already" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/typedef-named-like-a-global.c"
refuses "a void global" "'v' is declared 'void'" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/void-global.c"
refuses "a global initialised from a call" "'x' has to be initialised with something worked out before the program runs, C11 6.7.9p4, and this one cannot be" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/global-from-a-call.c"
refuses "a global initialised from another" "'b' has to be initialised with something worked out before the program runs, C11 6.7.9p4, and this one cannot be" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/global-from-another.c"
refuses "a global used above its declaration" "'x' is not declared" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/global-used-above.c"
refuses "a struct global with an initialiser" "'b' has to be initialised with something worked out before the program runs, C11 6.7.9p4, and the value of a 'struct pt' is not" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/global-struct-initialised.c"
refuses "a global array of no elements" "'a' is an array of no elements" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/global-array-of-no-elements.c"
# An address initialiser is written as its label: a string, `&` of a
# global, or a global array's name. `cc` also writes a label and a number,
# `&table[1]` as `_table+4`, and those three are refused here by name; the
# last two `cc` refuses as well.
refuses "a global pointer to an element" 'one with an offset is not yet' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/global-address-of-an-element.c"
refuses "a global pointer to an array plus a number" 'one with an offset is not yet' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/global-array-plus-a-number.c"
refuses "a global pointer to a string plus a number" 'one with an offset is not yet' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/global-string-plus-a-number.c"
refuses "a global int initialised with an address" "'x' has to be initialised with something worked out before the program runs, C11 6.7.9p4, and this one cannot be" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/global-int-from-an-address.c"
# It said *an address this cannot write* until 2026-09-29, as `&table[1]`
# does, and `cc` refuses it as no constant at all, which is what it says now.
refuses "a global pointer initialised from another" "'q' has to be initialised with something worked out before the program runs, C11 6.7.9p4, and this one cannot be" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/global-pointer-from-a-pointer.c"
# **`static`**, since 2026-09-29, ROADMAP 6.10's first part. Reserving the
# word is what refuses the first, which compiled until then; `cc` refuses
# the rest as well. Until ROADMAP 6.12's first part the word was first or
# not there, and `int static f(void)` was a syntax error; it is in the
# oracle now, and a parameter, a typedef and `static` twice are refused by
# what C11 says of storage classes. A member's specifiers have none, C11
# 6.7.2.1, so there it is still the grammar that refuses it.
refuses "'static' as a name" 'and found "="' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/static-as-a-name.c"
refuses "a 'static' definition after a declaration without it" "'f' is declared 'static' after a declaration without it" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/static-after-a-declaration-without-it.c"
refuses "a 'static' parameter" "'x' is a parameter declared 'static', and the one storage class a parameter may have is 'register', C11 6.7.6.3p2" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/static-parameter.c"
refuses "a 'static' member" 'and found "static"' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/static-member.c"
refuses "a 'static' typedef" "this declaration has 2 storage classes, and C11 6.7.1p2 allows one" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/static-typedef.c"
refuses "'static' twice" "this declaration has 2 storage classes, and C11 6.7.1p2 allows one" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/static-twice.c"
# **A `static` local**, since 2026-09-29, ROADMAP 6.10's second part. Its
# initialiser is a global's, so the `constants` pass refuses it for the same
# reasons; `cc` refuses the first three, and the ninth to the fourteenth,
# too. The five addresses with an offset, an array of no elements and a
# size past 2^63 it compiles. `&a` of a local was the first address no global could be given,
# and **it named a limit of this compiler until an attribute said whether
# an address starts at a label**: `rooted`, in the `constants` pass.
C6="has to be initialised with something worked out before the program runs, C11 6.7.9p4, and this one cannot be"
refuses "a static local from a variable" "'b' is 'static', and $C6" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/static-local-from-a-variable.c"
refuses "a static local from a call" "'b' is 'static', and $C6" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/static-local-from-a-call.c"
refuses "a static local from a local's address" "'p' is 'static', and $C6" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/static-local-address-of-a-local.c"
refuses "a static local from an address with an offset" "'p' is 'static', and is initialised with an address this cannot write" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/static-local-address-with-an-offset.c"
refuses "and from a member's address, through a struct" "'p' is 'static', and is initialised with an address this cannot write" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/static-local-member-address.c"
refuses "and from a number plus an array" "'p' is 'static', and is initialised with an address this cannot write" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/static-local-number-plus-an-array.c"
refuses "and from a member that is an array" "'q' is 'static', and is initialised with an address this cannot write" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/static-local-array-member.c"
refuses "and from one through a cast" "'p' is 'static', and is initialised with an address this cannot write" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/static-local-cast-address-with-an-offset.c"
refuses "a static local from a global pointer's value" "'p' is 'static', and $C6" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/static-local-from-a-global-pointer.c"
refuses "and from an element through one" "'p' is 'static', and $C6" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/static-local-through-a-global-pointer.c"
refuses "a static local declared twice" "'n' is declared twice" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/static-local-declared-twice.c"
refuses "a static local, then a local of its name" "'n' is declared twice" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/static-local-then-a-local.c"
refuses "a void static local" "'v' is declared 'void'" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/static-local-void.c"
refuses "a static struct from another" "'y' is 'static', and has to be initialised with something worked out before the program runs, C11 6.7.9p4, and the value of a 'struct s' is not" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/static-local-struct-initialised.c"
refuses "a static local array of no elements" "'a' is an array of no elements" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/static-local-array-of-no-elements.c"
refuses "a static local past 2^63" "'n' is 'static', and has to be initialised with something worked out before the program runs, C11 6.7.9p4, and this one is 'unsigned long' arithmetic past 2^63" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/static-local-sizeof-past-2-63.c"
# **`const`**, since 2026-09-29, ROADMAP 6.10's third part: C11 6.3.2.1p1's
# modifiable lvalue, which a `const` place is not and nor is a struct with
# a `const` member anywhere in it. `cc` refuses every one of these. Each
# way a place's type is reached has its own: a name, a `*` of a pointer, of
# one stepped on, of a sum either way round, a difference, a cast, an `&`,
# an assignment, a comma, a `?:` and a call, a member and a member's
# element, a typedef, and `const` written twice.
refuses "a const local assigned" "'=' changes something declared 'const', and C11 6.3.2.1p1 says nothing may" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/assign-a-const-local.c"
refuses "a const incremented" "'++' changes something declared 'const', and C11 6.3.2.1p1 says nothing may" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/increment-a-const.c"
refuses "a const long decremented, before" "'--' changes something declared 'const', and C11 6.3.2.1p1 says nothing may" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/decrement-a-const-before.c"
refuses "a const added to" "'+=' changes something declared 'const', and C11 6.3.2.1p1 says nothing may" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/add-to-a-const.c"
refuses "a const global assigned" "'=' changes something declared 'const', and C11 6.3.2.1p1 says nothing may" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/assign-a-const-global.c"
refuses "a const parameter assigned" "'=' changes something declared 'const', and C11 6.3.2.1p1 says nothing may" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/assign-a-const-parameter.c"
refuses "a static const assigned" "'=' changes something declared 'const', and C11 6.3.2.1p1 says nothing may" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/assign-a-const-static.c"
refuses "a const member assigned" "'=' changes something declared 'const', and C11 6.3.2.1p1 says nothing may" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/assign-a-const-member.c"
refuses "an element of a const array" "'=' changes something declared 'const', and C11 6.3.2.1p1 says nothing may" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/write-an-element-of-a-const-array.c"
refuses "a write through a pointer to const" "'=' changes something declared 'const', and C11 6.3.2.1p1 says nothing may" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/write-through-a-pointer-to-const.c"
refuses "and through one stepped on, '*p++'" "'=' changes something declared 'const', and C11 6.3.2.1p1 says nothing may" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/write-through-a-stepped-pointer-to-const.c"
refuses "and through a sum, '*(p + 1)'" "'=' changes something declared 'const', and C11 6.3.2.1p1 says nothing may" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/write-through-a-sum-to-const.c"
refuses "and through a cast to one" "'=' changes something declared 'const', and C11 6.3.2.1p1 says nothing may" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/write-through-a-cast-to-const.c"
refuses "and through a typedef of one" "'=' changes something declared 'const', and C11 6.3.2.1p1 says nothing may" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/write-through-a-typedef-to-const.c"
refuses "and through '&' of a const, '*&x'" "'=' changes something declared 'const', and C11 6.3.2.1p1 says nothing may" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/write-through-the-address-of-a-const.c"
refuses "and through an assignment" "'=' changes something declared 'const', and C11 6.3.2.1p1 says nothing may" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/write-through-an-assignment-to-const.c"
refuses "and through a comma" "'=' changes something declared 'const', and C11 6.3.2.1p1 says nothing may" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/write-through-a-comma-to-const.c"
refuses "and through '?:'" "'=' changes something declared 'const', and C11 6.3.2.1p1 says nothing may" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/write-through-a-choice-to-const.c"
refuses "and through a call that returns one" "'=' changes something declared 'const', and C11 6.3.2.1p1 says nothing may" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/write-through-a-call-to-const.c"
refuses "and through a sum with the pointer on the right" "'=' changes something declared 'const', and C11 6.3.2.1p1 says nothing may" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/write-through-a-number-plus-a-pointer-to-const.c"
refuses "and through a difference" "'=' changes something declared 'const', and C11 6.3.2.1p1 says nothing may" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/write-through-a-difference-to-const.c"
refuses "and one with it in a struct named by a typedef" "'struct out' has a 'const' member, so it is not assigned whole" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/copy-a-struct-with-a-const-member-through-a-typedef.c"
refuses "a const pointer moved" "'=' changes something declared 'const', and C11 6.3.2.1p1 says nothing may" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/move-a-const-pointer.c"
refuses "'const' before a typedef of a pointer, moved" "'=' changes something declared 'const', and C11 6.3.2.1p1 says nothing may" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/assign-a-const-typedef.c"
refuses "a member through a pointer to a const struct" "'=' changes something declared 'const', and C11 6.3.2.1p1 says nothing may" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/member-through-a-pointer-to-a-const-struct.c"
refuses "and an element of an array member" "'=' changes something declared 'const', and C11 6.3.2.1p1 says nothing may" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/element-of-a-member-of-a-const-struct.c"
refuses "'const' among the words of a type" "'=' changes something declared 'const', and C11 6.3.2.1p1 says nothing may" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/assign-a-const-among-the-words.c"
refuses "'const' twice is still const" "'=' changes something declared 'const', and C11 6.3.2.1p1 says nothing may" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/const-twice-still-const.c"
refuses "a struct with a const member, whole" "'struct s' has a 'const' member, so it is not assigned whole" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/copy-a-struct-with-a-const-member.c"
refuses "and one with it a struct further in" "'struct out' has a 'const' member, so it is not assigned whole" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/copy-a-struct-with-a-const-member-inside.c"
refuses "'const' as a name" 'or name, and found "="' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/const-as-a-name.c"
refuses "a function returning const, then not" "'f' is declared twice, returning a different type each time" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/const-return-then-plain.c"
refuses "a typedef, const and then not" "'t' is a typedef twice, for two different types" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/typedef-twice-const-and-not.c"
# **C11's 44 keywords are all reserved**, since ROADMAP 6.12's first part.
# Until then 21 of them were names, and `int float = 1;` compiled, where
# `cc` refuses each; so the first twenty-one here are refusals that used to
# be answers. A keyword whose feature is not in the subset is refused by
# name wherever it is used, and the three behind a `__STDC_NO_*__` macro
# say so; `auto` and `register` are in, and in the oracle, and `extern` and
# `_Static_assert` have been since the second part, when their programs
# moved there.
refuses "'auto' as a name" 'and found "="' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-auto-as-a-name.c"
refuses "'double' as a name" 'and found "="' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-double-as-a-name.c"
refuses "'enum' as a name" 'and found "enum"' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-enum-as-a-name.c"
refuses "'extern' as a name" 'and found "="' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-extern-as-a-name.c"
refuses "'float' as a name" 'and found "="' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-float-as-a-name.c"
refuses "'inline' as a name" 'and found "="' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-inline-as-a-name.c"
refuses "'register' as a name" 'and found "="' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-register-as-a-name.c"
refuses "'restrict' as a name" 'and found "="' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-restrict-as-a-name.c"
refuses "'short' as a name" 'and found "="' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-short-as-a-name.c"
refuses "'union' as a name" 'and found "union"' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-union-as-a-name.c"
refuses "'volatile' as a name" 'and found "="' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-volatile-as-a-name.c"
refuses "'_Alignas' as a name" 'and found "="' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-_Alignas-as-a-name.c"
refuses "'_Alignof' as a name" 'and found "_Alignof"' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-_Alignof-as-a-name.c"
refuses "'_Atomic' as a name" 'and found "="' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-_Atomic-as-a-name.c"
refuses "'_Bool' as a name" 'and found "="' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-_Bool-as-a-name.c"
refuses "'_Complex' as a name" 'and found "="' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-_Complex-as-a-name.c"
refuses "'_Generic' as a name" 'and found "_Generic"' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-_Generic-as-a-name.c"
refuses "'_Imaginary' as a name" 'and found "="' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-_Imaginary-as-a-name.c"
refuses "'_Noreturn' as a name" 'and found "="' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-_Noreturn-as-a-name.c"
refuses "'_Static_assert' as a name" 'and found "_Static_assert"' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-_Static_assert-as-a-name.c"
refuses "'_Thread_local' as a name" 'and found "="' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-_Thread_local-as-a-name.c"
refuses "'double' in use" "'double' is C11's, and not this subset's yet" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-double-in-use.c"
refuses "'float' in use" "'float' is C11's, and not this subset's yet" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-float-in-use.c"
# `short` was refused here by name until ROADMAP 6.15's second part, and
# is in the oracle; what `cc` refuses of it is a second word with it.
refuses "short long" "'short long' is not one of the types C11 6.7.2p2 lists" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/short-long.c"
refuses "short short" "'short short' is not one of the types C11 6.7.2p2 lists" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/short-short.c"
# `_Bool` was refused here by name until ROADMAP 6.15's third part, and is
# in the oracle; `cc` refuses it signed or unsigned.
refuses "unsigned _Bool" "'unsigned _Bool' is not one of the types C11 6.7.2p2 lists" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/unsigned-bool.c"
refuses "'_Thread_local' in use" "'_Thread_local' is C11's, and not this subset's yet" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-_Thread_local-in-use.c"
refuses "'volatile' in use" "'volatile' is C11's, and not this subset's yet" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-volatile-in-use.c"
refuses "'restrict' in use" "'restrict' is C11's, and not this subset's yet" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-restrict-in-use.c"
refuses "'inline' in use" "'inline' is C11's, and not this subset's yet" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-inline-in-use.c"
refuses "'_Noreturn' in use" "'_Noreturn' is C11's, and not this subset's yet" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-_Noreturn-in-use.c"
refuses "'_Alignas' in use" "'_Alignas' is C11's, and not this subset's yet" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-_Alignas-in-use.c"
# `enum` was refused here by name until ROADMAP 6.15's fourth part. This
# program names one before its list, which C11 does not have, and `cc`
# refuses it for that now; the rest of what `cc` refuses of one is with
# the integer types, below.
refuses "'enum' named before its list" "'enum colour' is named before its list, and C11 6.7.2.3p3 has no enumeration declared without one" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-enum-in-use.c"
refuses "'union' in use" "'union' is C11's, and not this subset's yet" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-union-in-use.c"
refuses "'_Alignof' in use" "'_Alignof' is C11's, and not this subset's yet" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-_Alignof-in-use.c"
refuses "'_Generic' in use" "'_Generic' is C11's, and not this subset's yet" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-_Generic-in-use.c"
refuses "'_Complex' in use" "'_Complex' is optional in C11, and left out here, as __STDC_NO_COMPLEX__ says" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-_Complex-in-use.c"
refuses "'_Imaginary' in use" "'_Imaginary' is optional in C11, and left out here, as __STDC_NO_COMPLEX__ says" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-_Imaginary-in-use.c"
refuses "'_Atomic' in use" "'_Atomic' is optional in C11, and left out here, as __STDC_NO_ATOMICS__ says" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/keyword-_Atomic-in-use.c"
# **The words of a type are counted, not ordered**, C11 6.7.2p2: `int long`
# is `long`, and a list that is none of the types it names is refused with
# the words as written. `cc` refuses each. `long long` was refused here by
# name until ROADMAP 6.15's first part, and is in the oracle.
refuses "long long long" "'long long long' is not one of the types C11 6.7.2p2 lists" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/long-long-long.c"
refuses "long char" "'long char' is not one of the types C11 6.7.2p2 lists" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/long-char.c"
refuses "int int" "'int int' is not one of the types C11 6.7.2p2 lists" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/int-int.c"
# **Storage classes**, C11 6.7.1: one to a declaration, where the words of
# the type are, and `typedef` counted among them. `auto` and `register` are
# a block's, and a parameter's only one is `register`. `cc` refuses all but
# the last three. A `register` array it compiles, and every use of one but
# `sizeof` is undefined; a typedef of a function type and one in a block are
# C, and this subset's in a later part or entry.
refuses "two storage classes" "this declaration has 2 storage classes, and C11 6.7.1p2 allows one" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/two-storage-classes.c"
refuses "'auto' at file scope" "'x' is declared 'auto' at file scope, which C11 6.9p2 forbids" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/auto-at-file-scope.c"
refuses "'register' at file scope" "'x' is declared 'register' at file scope, which C11 6.9p2 forbids" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/register-at-file-scope.c"
refuses "an 'auto' parameter" "'x' is a parameter declared 'auto', and the one storage class a parameter may have is 'register', C11 6.7.6.3p2" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/auto-parameter.c"
refuses "the address of a 'register' local" "'r' is declared 'register', and C11 6.5.3.2p1 forbids taking its address" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/address-of-a-register.c"
refuses "a typedef with an initialiser" "'T' is a typedef, and only an object has an initialiser, C11 6.7.9" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/typedef-with-an-initialiser.c"
refuses "a 'register' array" "'a' is a 'register' array, and C11 6.3.2.1p3 makes using one undefined" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/register-array.c"
refuses "a definition declared typedef" "'f' is a function's definition declared 'typedef', which C11 6.9.1p2 forbids" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/definition-declared-typedef.c"
# **A declaration of several names, and the rest of a declaration's
# places**, since ROADMAP 6.12's second part. A name declared twice in one
# list is refused as it is in two, and so is a global given a second type or
# a second initialiser; a second declaration without one is C11 6.9.2's
# tentative definition, and `int x; int x;` is in the oracle, where until
# then it was refused. `cc` refuses all of these but the last two, which are
# this subset's: an identifier list's declarations are one name each and in
# the list's order.
refuses "one name twice in a list" "'a' is declared twice" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/two-declarators-one-name.c"
refuses "a global with two types" "'x' is declared again with another type, C11 6.7p4" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/global-list-one-name-two-types.c"
refuses "a global array, then not" "'a' is declared again with another type, C11 6.7p4" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/global-array-then-scalar.c"
refuses "a global initialised twice in one list" "'x' is defined twice, with an initialiser each" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/global-list-defined-twice.c"
refuses "a global initialised, declared, and initialised again" "'x' is defined twice, with an initialiser each" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/global-defined-around-a-tentative.c"
refuses "an 'extern' in a block with an initialiser" "'x' is declared 'extern' in a block, and C11 6.7.9p5 gives it no initialiser" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/extern-initialised-in-a-block.c"
refuses "'static' after 'extern'" "'x' is declared 'static' after a declaration without it, C11 6.2.2p7" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/static-after-extern.c"
refuses "an 'extern' in a block of another type" "'x' is declared again with another type, C11 6.7p4" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/extern-in-a-block-of-another-type.c"
refuses "a static assertion that fails" "static assertion failed: int is eight bytes" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/static-assert-fails.c"
refuses "and one in a block" "static assertion failed: zero" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/static-assert-fails-in-a-block.c"
refuses "a static assertion of a variable" "'_Static_assert' has to be worked out before the program runs, C11 6.7.10p3, and this cannot be" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/static-assert-not-constant.c"
refuses "a 'for' declaring a static" "a 'for' declares only objects that are 'auto' or 'register', C11 6.8.5p3" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/for-declares-a-static.c"
refuses "a 'for' declaring a typedef" "a 'for' declares only objects that are 'auto' or 'register', C11 6.8.5p3" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/for-declares-a-typedef.c"
refuses "an unnamed parameter in a definition" "a parameter of a function's definition has a name, C11 6.9.1p5" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/unnamed-parameter-in-a-definition.c"
refuses "an identifier list with a name undeclared" "'f' does not declare one parameter for each name in its list, in the list's order: C11 6.9.1p6 asks for one each, and this subset for the order too" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/identifier-list-undeclared.c"
refuses "an identifier list with a name twice" "'f' has a name twice in its list of parameters, C11 6.9.1p6" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/identifier-list-named-twice.c"
refuses "an identifier list with a name it lacks declared" "'f' does not declare one parameter for each name in its list, in the list's order: C11 6.9.1p6 asks for one each, and this subset for the order too" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/identifier-list-declares-another.c"
refuses "an identifier list declared in another order" "'f' does not declare one parameter for each name in its list, in the list's order: C11 6.9.1p6 asks for one each, and this subset for the order too" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/identifier-list-in-another-order.c"
refuses "an identifier list with two in one declaration" 'and found ","' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/identifier-list-two-in-one-declaration.c"
refuses "an identifier list in a prototype" 'or {, and found ";"' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/identifier-list-of-a-prototype.c"
# **Tags**, since ROADMAP 6.12's third part: a struct may be defined in a
# block, with the block's scope, or with no tag, and declared before it is
# defined; a pointer to one that is not complete yet is C, and what needs
# its size is refused until it is, as `cc` refuses it. A tag defined twice in
# one block is refused as at file scope, and so is a typedef given two types.
refuses "a local of a struct not complete" "'x' is declared of 'struct s', which is not complete here, C11 6.7p7" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/incomplete-struct-local.c"
refuses "arithmetic on a pointer to one" "'+' counts in 'struct s', which is not complete here, C11 6.5.6" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/incomplete-struct-arithmetic.c"
refuses "and '++'" "'++' counts in 'struct s', which is not complete here, C11 6.5.6" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/incomplete-struct-incremented.c"
refuses "'*' of a pointer to one" "'*' reads a 'struct s', which is not complete here" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/incomplete-struct-dereferenced.c"
refuses "'sizeof' of one" "'sizeof' of 'struct s', which is not complete here, C11 6.5.3.4" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/incomplete-struct-sizeof.c"
refuses "a member through a pointer to one" "'*' reads a 'struct s', which is not complete here" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/incomplete-struct-member.c"
refuses "two structs with no tag, which are two types" "'struct (anonymous)' is assigned 'struct (anonymous)', and a struct takes only its own kind" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/untagged-structs-are-two-types.c"
refuses "a struct's members, not those of one inside it" "'struct outer' has no member 'k'" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/nested-struct-members-stay-inside.c"
refuses "a struct defined twice in a block" "'struct t' is defined twice" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-defined-twice-in-a-block.c"
refuses "a typedef given two types in a block" "'T' is a typedef twice, for two different types" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/typedef-twice-in-a-block.c"
# **Types built by declarators**, since ROADMAP 6.12's fourth part: arrays
# of arrays, a pointer to an array, abstract declarators and an array
# parameter are in the oracle, and `typedef int v[3];` moved there from
# here. `cc` refuses the four below as C does. Two more were C, a pointer
# to a function, read so as to be refused by name; they are in the oracle
# since ROADMAP 6.14's first part.
refuses "a cast to an array" "a cast to an array is not C, C11 6.5.4" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/cast-to-an-array.c"
refuses "an assignment to a row of an array" "an array is not something a value can be put in" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/assign-to-a-row.c"
refuses "an element of a const array of arrays" "'=' changes something declared 'const', and C11 6.3.2.1p1 says nothing may" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/assign-a-const-element-of-a-row.c"
refuses "an array of arrays of no elements" "an array of no elements, which C11 6.7.6.2 forbids and this cc allows as an extension" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/array-of-arrays-of-no-elements.c"
# **Initialisers in braces**, since ROADMAP 6.13's first part: arrays and
# scalars, at file scope, in a block and `static`. `cc` refuses each of
# these, some only with `-pedantic-errors`, since it warns about what C11
# 6.7.9p2 makes a constraint: more values than the object has room for, a
# string longer than its array, and braces around a scalar's braces.
refuses "more values than an array has room for" "'a' is given more initialisers than it has room for, C11 6.7.9p2" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/init-excess-array.c"
refuses "and in a block, in an inner list" "'a' is given more initialisers than it has room for, C11 6.7.9p2" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/init-excess-in-a-block.c"
refuses "two values for a scalar" "'x' is given more initialisers than it has room for, C11 6.7.9p2" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/init-excess-scalar.c"
refuses "'{}', which is C23's" "'a' is initialised with '{}', which is C23's, not C11's" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/init-empty-braces.c"
refuses "a global's element not worked out" "'a' has to be initialised with something worked out before the program runs, C11 6.7.9p4" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/init-global-not-constant.c"
refuses "and a static's" "'a' has to be initialised with something worked out before the program runs, C11 6.7.9p4" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/init-static-not-constant.c"
refuses "a string longer than its array" "'s' is initialised with a string longer than it, C11 6.7.9p2" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/init-string-too-long.c"
refuses "an array from another array" "'a' is an array, initialised with a list in braces or, if it is of 'char', a string, C11 6.7.9p16" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/init-array-from-an-array.c"
refuses "braces around a scalar's braces" "'x' has braces around a scalar's braces, and C11 6.7.9p11 allows one pair" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/init-braces-around-braces.c"
refuses "a list starting part-way through an element" "'a' has a list in braces that starts part-way through an element" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/init-braces-mid-element.c"
refuses "a struct where a scalar is wanted" "'x' is given 'struct p' where a number or a pointer is wanted" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/init-struct-in-a-scalar.c"
# **Structs in braces**, since ROADMAP 6.13's second part. `cc` refuses
# each. Leaving out the braces of a member that is an array or a struct was
# refused here too, until the third part's walk could find the scalar after
# the last one in a struct; that program is in the oracle now.
refuses "more values than a struct has members" "'x' is given more initialisers than it has room for, C11 6.7.9p2" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/init-struct-excess.c"
refuses "a struct member given another struct" "'x' is given 'struct q' where 'struct p' is wanted" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/init-struct-of-another-kind.c"
refuses "a struct value at file scope" "'x' has to be initialised with something worked out before the program runs, C11 6.7.9p4" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/init-struct-value-at-file-scope.c"
refuses "more structs than an array has room for" "'two' is given more initialisers than it has room for, C11 6.7.9p2" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/init-struct-list-too-long.c"
# **Designators**, since ROADMAP 6.13's third part. `cc` refuses all but the
# last three. Those are this subset's: an index that is an expression and
# not a number written out, since a value is placed before the `constants`
# pass works any out; a struct too big for the map of its bytes the walk
# reads; and an object nested more than eight levels deep, which is as far
# down as the walk that places a value is written out.
refuses "a designator past an array's end" "'a' has a designator past the end of an array, C11 6.7.9p6" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/init-designator-past-the-end.c"
refuses "a designator naming no member" "'x' has a designator naming no member of the struct, C11 6.7.9p7" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/init-designator-no-member.c"
refuses "'.' for an array" "'a' has a '.' designator for something that is not a struct, C11 6.7.9p7" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/init-designator-dot-on-an-array.c"
refuses "'[ ]' for a struct" "'x' has a '[ ]' designator for something that is not an array, C11 6.7.9p6" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/init-designator-index-on-a-struct.c"
refuses "a designator for a scalar" "'x' has a '.' designator for something that is not a struct, C11 6.7.9p7" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/init-designator-on-a-scalar.c"
refuses "an index that is not a constant" "'a' has an array designator that is not a number written out" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/init-designator-not-constant.c"
refuses "an index that is worked out" "'a' has an array designator that is not a number written out" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/init-designator-worked-out.c"
refuses "a struct too big for its byte map" "'g' is initialised through a struct too big for this subset's map of its bytes" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/init-struct-too-big-for-its-map.c"
refuses "an object nested nine deep" "'a' is initialised through more levels of arrays and structs than this subset walks, which is eight" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/init-nested-too-deep.c"
# **The rest of ROADMAP 6.13's list**, which closed with its fourth part:
# an array from a scalar, a struct from a scalar, and an array with neither
# a size nor an initialiser, in a block; at file scope `cc` takes that one
# as a tentative definition of one element.
refuses "an array from a scalar" "'a' is an array, initialised with a list in braces or, if it is of 'char', a string, C11 6.7.9p16" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/init-array-from-a-scalar.c"
refuses "a struct from a scalar" "'x' is a 'struct s' initialised from something that is not a struct" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/init-struct-from-a-scalar.c"
refuses "an array with neither a size nor an initialiser" "expected [ or =, and found \";\"" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/array-of-no-size-in-a-block.c"
# **Compound literals**, since ROADMAP 6.13's fourth part. Their object is
# initialised as a declaration's is, so what a declaration's initialiser is
# refused for, a compound literal's is, under a name of its own. `cc`
# refuses all but one: a struct's compound literal initialising a global,
# which it takes as an extension and C11 6.7.9p4 does not, since a struct's
# value is no constant. A variable-length array is no compound literal's
# type, C11 6.5.2.5p1, and a count here is a number written out.
refuses "a compound literal of '{}'" "'(compound literal)' is initialised with '{}', which is C23's, not C11's" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/compound-literal-empty-braces.c"
refuses "more values than a compound literal has room for" "'(compound literal)' is given more initialisers than it has room for, C11 6.7.9p2" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/compound-literal-excess.c"
refuses "a string longer than a compound literal" "'(compound literal)' is initialised with a string longer than it, C11 6.7.9p2" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/compound-literal-string-too-long.c"
refuses "a compound literal at file scope not worked out" "'(compound literal)' has to be initialised with something worked out before the program runs, C11 6.7.9p4" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/compound-literal-not-constant-at-file-scope.c"
refuses "a block's compound literal in a static" "'p' is 'static', and has to be initialised with something worked out before the program runs, C11 6.7.9p4, and this one cannot be" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/compound-literal-in-a-static.c"
refuses "and its address" "'p' is 'static', and has to be initialised with something worked out before the program runs, C11 6.7.9p4, and this one cannot be" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/compound-literal-address-in-a-static.c"
refuses "a struct's compound literal initialising a global" "'g' has to be initialised with something worked out before the program runs, C11 6.7.9p4, and the value of a 'struct pair' is not" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/compound-literal-struct-at-file-scope.c"
refuses "a compound literal of an incomplete struct" "a compound literal is of 'struct nope', which is not complete here, C11 6.5.2.5p1" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/compound-literal-incomplete.c"
refuses "a compound literal of void" "a compound literal is of 'void', and an object's type has to be complete, C11 6.5.2.5p1" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/compound-literal-void.c"
refuses "a compound literal of variable length" "expected integer or ], and found \"n\"" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/compound-literal-variable-length.c"
# **Pointers to functions**, since ROADMAP 6.14's first part: a function
# is a value, its own address, and has no size, no order and no place a
# value can be put. `cc -pedantic-errors` refuses each; it counts in bytes
# without the flag, as GNU C does.
refuses "arithmetic on a pointer to a function" "'+' on a pointer to a function counts in something of no size, C11 6.5.6" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/function-pointer-arithmetic.c"
refuses "and '++' on one" "'++' on a pointer to a function counts in something of no size, C11 6.5.6" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/function-pointer-incremented.c"
refuses "sizeof a function" "'sizeof' of a function has no size, C11 6.5.3.4" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/sizeof-a-function.c"
refuses "an assignment to a function" "a function is not something a value can be put in, C11 6.3.2.1p1" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/assign-to-a-function.c"
refuses "and through a pointer to one" "a function is not something a value can be put in, C11 6.3.2.1p1" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/assign-through-a-function-pointer.c"
refuses "two pointers to functions ordered" "'<' orders pointers to functions, and C11 6.5.8 orders only pointers to objects" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/function-pointers-ordered.c"
# And a parameter's name in a pointer to a function's parentheses is in no
# scope after them, C11 6.2.1p4's function prototype scope.
refuses "a pointer to a function's parameter, out of scope" "'x' is not declared" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/function-pointer-parameter-out-of-scope.c"
# **Calls through a pointer**, since ROADMAP 6.14's second part, are
# counted and checked against the pointer's parameters as a call by name
# is against the function's. `cc` refuses each.
refuses "a call of a number" "'x' is called, and it is neither a function nor a pointer to one, C11 6.5.2.2p1" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/call-a-number.c"
refuses "too few arguments through a pointer" "'f' takes 2 arguments, and this gives 1" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/call-through-a-pointer-too-few.c"
refuses "too many through '*' of one" "a pointer to a function takes 2 arguments, and this gives 3" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/call-through-a-pointer-too-many.c"
refuses "a number where a pointer's parameter is a struct" "'f' is given a struct where its parameter is not that struct" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/call-through-a-pointer-number-for-a-struct.c"
# A name in a call's arguments or its callee's subscript is not being
# called, and is refused in the words of a name, not of a call.
refuses "an undeclared name in an argument" "'y' is not declared" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/undeclared-in-an-argument.c"
refuses "and in a callee's subscript" "'i' is not declared" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/undeclared-in-a-callee-subscript.c"
# **A function's address as data**, since ROADMAP 6.14's third part: its
# name is worked out before the program runs, and a pointer's value is
# not, alone or in braces, as `cc` says.
refuses "a global from another's pointer to a function" "'b' has to be initialised with something worked out before the program runs, C11 6.7.9p4" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/global-from-a-function-pointer.c"
refuses "and a table of them" "'t' has to be initialised with something worked out before the program runs, C11 6.7.9p4" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/global-table-from-a-function-pointer.c"
# **The types around pointers to functions**, since ROADMAP 6.14's
# fourth part. `cc` refuses all but one: a function declared through a
# typedef of its type, which C allows and this subset refuses by name.
# The last three are shapes C forbids, which reach this subset as
# syntax errors, since no declarator here can write one.
refuses "a pointer to a function given another type" "'f' is given a pointer to a function of another type" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/function-pointer-of-another-type.c"
refuses "and assigned one" "'=' is given a pointer to a function of another type" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/function-pointer-assigned-another-type.c"
refuses "and a global" "'g' is given a pointer to a function of another type" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/function-pointer-global-of-another-type.c"
refuses "and a member in braces" "'x' is given a pointer to a function of another type" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/function-pointer-member-of-another-type.c"
refuses "a function to a 'void *'" "'p' is given a pointer to a function, where a pointer to something else goes" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/function-to-void-pointer.c"
refuses "a pointer to an int to a pointer to a function" "'f' is given a pointer to something that is not a function, where a pointer to a function goes" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/object-pointer-to-function-pointer.c"
refuses "a function to a number" "'n' is given a pointer to a function, where a number goes" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/function-to-a-number.c"
refuses "a function declared through a typedef" "'add' is declared through a typedef of a function's type" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/function-declared-through-a-typedef.c"
refuses "a function returning a function" "expected ; or {, and found \"(\"" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/function-returning-a-function.c"
refuses "a function returning an array" "expected *, and found \"f\"" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/function-returning-an-array.c"
refuses "an array of functions" "expected [, =, , or ;, and found \"(\"" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/array-of-functions.c"
# **Enumerations**, since ROADMAP 6.15's fourth part. `cc` refuses all but
# the last, a character constant as an enumerator's value, which this
# subset does not work out before the `types` pass and refuses by name.
refuses "an enumerator twice" "'A' is declared twice" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/enumerator-twice.c"
refuses "an enumerator named as a global already" "'A' is declared twice" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/enumerator-named-already.c"
refuses "an enumerator past an int" "'X' is 4294967296, past an int's range" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/enumerator-past-int.c"
refuses "and one counted past it" "'N' is 2147483648, past an int's range" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/enumerator-counted-past-int.c"
refuses "an enumeration defined twice" "'enum e' is defined twice" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/enum-defined-twice.c"
refuses "an assignment to an enumerator" "'RED' is an enumeration constant, and a constant is not something a value can be put in" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/assign-to-an-enumerator.c"
refuses "'&' of an enumerator" "'&' wants somewhere a value is kept, and 'RED' is an enumeration constant" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/address-of-an-enumerator.c"
refuses "'++' of an enumerator" "'++' wants somewhere a value is kept" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/increment-an-enumerator.c"
refuses "an enumerator from a global" "'A' is given a value this subset does not work out" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/enumerator-not-constant.c"
refuses "an enumerator from a character" "'A' is given a value this subset does not work out" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/enumerator-from-a-character.c"
# **A call by name is still a call by name**, since ROADMAP 6.14's second
# part made every call one node: `bl _apply`, and a call through a
# pointer is a `blr`. Both ways the program says the same, so only the
# assembly can show which it was.
fncalls=$(bounded "$phx" --driver arm64 "$root/languages/c/c-arm64.phx" "$root/languages/c/tests/oracle/fnptr-calls.c" 2>&1)
if printf '%s\n' "$fncalls" | grep -q '	bl _apply$' && printf '%s\n' "$fncalls" | grep -q '	blr x17$'; then
    report pass "a call by name is 'bl', and one through a pointer 'blr'"
else
    report fail "a call by name is 'bl', and one through a pointer 'blr'" "the assembly for fnptr-calls.c has not both"
fi
# **Every program in refused/ is asserted by name**, since 2026-09-29, when
# three from ROADMAP 6.9's second part were found asserted by nothing: a
# file there that no line names is refused for whatever reason it likes.
# The names are looked for in this script, which is where they are asserted.
unnamed=""
for src in "$r"/*.c; do
    grep -qF -- "\$r/$(basename "$src")\"" "$root/tests/run.sh" || unnamed="$unnamed $(basename "$src")"
done
if [ -z "$unnamed" ]; then
    report pass "every refused C program is asserted by name"
else
    report fail "every refused C program is asserted by name" "not named:$unnamed"
fi
if [ "$(uname -m)" = "arm64" ]; then
    if co=$(harness "$root/languages/c/tests/oracle/run.sh" 2>&1); then
        n=$(printf '%s' "$co" | grep -c '^  ok')
        report pass "$n C programs exit with what cc makes them exit with"
    else
        report fail "C programs agree with cc"
        printf '%s\n' "$co" | grep -A3 FAIL | sed 's/^/        /' | head -12
    fi
    # The calling convention, held against cc's rather than against itself:
    # a caller and a callee in two files, each compiled by each. The oracle
    # cannot see a struct passed wrongly when both ends are Phoenix's, and
    # this is the only witness for the caller's copy of a large one.
    if ab=$(harness "$root/languages/c/tests/abi/run.sh" 2>&1); then
        report pass "structs pass between Phoenix's code and cc's, both ways"
    else
        report fail "structs pass between Phoenix's code and cc's, both ways"
        printf '%s\n' "$ab" | grep FAIL | sed 's/^/        /' | head -4
    fi
    # **Linkage, which one file cannot show**, since 2026-09-29, ROADMAP
    # 6.10: two files each with `static` names of the other's, linked.
    if lk=$(harness "$root/languages/c/tests/link/run.sh" 2>&1); then
        report pass "a static name is its own file's, linked beside another"
    else
        report fail "a static name is its own file's, linked beside another"
        printf '%s\n' "$lk" | grep FAIL | sed 's/^/        /' | head -4
    fi
    # **The two divergences are oracle programs now.** `sizeof(sizeof(int))`
    # and `sizeof` of a pointer difference were 8 under `cc` and 4 here, pinned
    # with both answers from 2026-09-22, because C makes both a `long` and the
    # subset had none. `long` arrived on 2026-09-23 and both moved into
    # `tests/oracle/`, where the count above includes them.
else
    skip 2 "the C oracle and the calling-convention test need an arm64 cc, and this machine is not arm64"
fi

# The log of every program stopped anywhere above. The two the limit's own
# checks stop on purpose are not in it.
echo "the whole run"
if [ ! -s "$PHX_LIMIT_LOG" ]; then
    report pass "every program the suite ran finished"
else
    report fail "every program the suite ran finished" \
                "$(wc -l < "$PHX_LIMIT_LOG" | tr -d ' ') did not, in $PHX_LIMIT_LOG"
    sed "s#$root/##g; s/^/        /" "$PHX_LIMIT_LOG" | head -10
fi

echo
if [ "$skipped" -eq 0 ]; then
    printf '%d passed, %d failed\n' "$pass" "$fail"
else
    printf '%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skipped"
fi

# The count tests/counts.sh deliberately leaves alone, because a test that
# asserts how many tests there are changes the answer. It is held here instead,
# after the summary, where the number is final and nothing is still counting --
# so this can fail the run without being in it.
#
# Only a **full** run can judge it. The records quote what the suite does when
# everything it needs is present, and a machine without `fpc` or Solveig is
# right to report a smaller number -- failing there would make the check a
# claim about the machine rather than about the records.
#
# **The README's Building paragraph makes three more claims**: how many of
# the checks need only what is vendored here, out of how many, and what a
# run with none of the three optional oracles prints. They went stale
# together for two days, 291 and 283 where the tree said otherwise, because
# nothing judged them. A full run holds the three against each other; a run
# with exactly those oracles missing holds the last against itself.
bare=$(grep -oE '[0-9]+ passed, 0 failed and [0-9]+ skipped' "$root/README.md" \
       | head -1 | sed 's/ passed, 0 failed and / /; s/ skipped//')
bare_pass=${bare% *}; bare_skip=${bare#* }
need=$(grep -oE '[0-9]+ of the [0-9]+ need only' "$root/README.md" \
       | head -1 | sed 's/ of the / /; s/ need only//')
need_n=${need% *}; need_of=${need#* }
if [ "$skipped" -ne 0 ]; then
    if [ "$absent" -eq 3 ] && [ "$skipped" = "$bare_skip" ]; then
        if [ "$pass" != "$bare_pass" ]; then
            printf '  FAIL  with fpc, Solveig and z80asm absent this is %d passed and %d skipped, and README.md says %s and %s\n' \
                   "$pass" "$skipped" "$bare_pass" "$bare_skip"
            fail=$((fail + 1))
        fi
    else
        printf '  --    %d skipped, so the records'"'"' own count is not judged here\n' \
               "$skipped"
    fi
else
    stale=""
    readme=$(sed -n 's/^make test .*# \([0-9]*\) checks.*/\1/p' \
                 "$root/README.md" | head -1)
    [ "$readme" = "$pass" ] || stale="$stale README.md says $readme."
    [ "$need_of" = "$pass" ] || stale="$stale README.md's Building paragraph says $need_n of $need_of."
    [ "$need_n" = "$bare_pass" ] && [ $((bare_pass + bare_skip)) = "$pass" ] \
        || stale="$stale README.md's Building paragraph says $need_n need only what is here, and that a bare run is $bare_pass passed and $bare_skip skipped."

    chg=$(grep -m1 '^\*\*Tests:\*\*' "$root/docs/CHANGELOG.md" \
          | sed -n 's/.*→ \([0-9]*\).*/\1/p')
    [ "$chg" = "$pass" ] || stale="$stale CHANGELOG.md's newest entry says $chg."

    if [ -n "$stale" ]; then
        printf '  FAIL  the records say how many checks there are, and it is not %d:%s\n' \
               "$pass" "$stale"
        fail=$((fail + 1))
    fi
fi

[ "$fail" -eq 0 ]
