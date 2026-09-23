#!/bin/sh
# tests/run.sh -- what Phoenix is expected to do, and what it is expected to
# refuse. Run from the repository root, or by `make test`.

set -u

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
phx="$root/bin/phx"
pass=0
fail=0
skipped=0

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
    if out=$("$phx" --quiet "$@" 2>&1); then
        report pass "$what"
    else
        report fail "$what" "$(printf '%s' "$out" | head -2 | tr '\n' ' ')"
    fi
}

# refuses <what> <expected text> <args...>
refuses() {
    what=$1; _want=$2; shift 2
    if out=$("$phx" --quiet "$@" 2>&1); then
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
    got=$("$phx" "$@" 2>&1)
    if [ "$got" = "$_want" ]; then
        report pass "$what"
    else
        report fail "$what" "wanted '$_want', got '$got'"
    fi
}

# warns <what> <expected text> <args...>
warns() {
    what=$1; _want=$2; shift 2
    out=$("$phx" --quiet "$@" 2>&1)
    if printf '%s' "$out" | grep -qF -- "$_want"; then
        report pass "$what"
    else
        report fail "$what" "no warning matching '$_want'"
    fi
}

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
# of the description.
if out=$("$phx" --quiet "$root/tests/grammars/one-complaint.phx" \
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
shown=$("$phx" --run show --show show \
        "$root/tests/grammars/expression-only.phx" \
        "$root/tests/sources/an-expression.txt" 2>/dev/null)
if [ "$shown" = "(((a + (2 * -b)) < 10) and not c)" ]; then
    report pass "the module's precedence, rendered back"
else
    report fail "the module's precedence, rendered back" "got: $shown"
fi

# calc's own grammar defines neither boolean operators nor unary minus; all of
# it arrives with the module, and calc only answers for the nodes.
if "$phx" --run emit-c "$root/languages/calc/calc-c.phx" "$root/languages/calc/programs/logic.calc" \
        > "$tmp0/logic.c" 2>/dev/null \
   && cc -Wall -Werror -o "$tmp0/logic" "$tmp0/logic.c" 2>/dev/null; then
    got=$("$tmp0/logic")
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
listed=$("$phx" --imports "$root/languages/calc/calc-c.phx" 2>/dev/null)
seen=$(printf '%s\n' "$listed" | wc -l | tr -d ' ')
uniq=$(printf '%s\n' "$listed" | sort -u | wc -l | tr -d ' ')
if [ "$seen" = "4" ] && [ "$uniq" = "4" ]; then
    report pass "each file appears once"
else
    report fail "each file appears once" "listed $seen, distinct $uniq, wanted 4 and 4"
fi

# A message about an imported file has to name *that* file and its own line
# numbers, not a position in a buffer nobody wrote.
out=$("$phx" --quiet "$root/tests/grammars/duplicate-rule.phx" 2>&1)
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
nodes=$("$phx" --nodes "$root/languages/calc/calc-c.phx" 2>/dev/null)
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
tree=$("$phx" --tree "$root/languages/calc/calc-c.phx" "$root/languages/calc/programs/sum.calc" 2>/dev/null)
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
"$phx" --raw "$root/tests/grammars/embed.phx" "$root/tests/sources/zero.txt" \
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
if "$phx" --imports "$root/languages/awk/awk-c.phx" 2>/dev/null \
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
out=$("$phx" --quiet "$inc" "$src/uses-broken.inc" 2>&1)
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
got=$("$phx" "$root/tests/grammars/names.phx" "$root/tests/sources/names.txt" 2>&1 \
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
widths=$("$phx" --raw --driver widths "$inc" "$src/main.inc" 2>/dev/null \
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
before=$("$phx" --driver spans "$fold" "$arith" 2>/dev/null)
rootspan=${before##*@}
after=$("$phx" --driver folded-spans "$fold" "$arith" 2>/dev/null)
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

# The default driver is the first declared, and it compiles.
if "$phx" --quiet "$root/languages/calc/calc-c.phx" "$root/languages/calc/programs/sum.calc" \
        > /dev/null 2>&1; then
    report pass "the default driver runs"
else
    report fail "the default driver runs"
fi

# A driver with no `->` is a validation run: it says nothing and answers with
# its status.
out=$("$phx" --driver check "$root/languages/calc/calc-c.phx" \
        "$root/languages/calc/programs/fizz.calc" 2>&1)
if [ -z "$out" ]; then
    report pass "a check driver says nothing"
else
    report fail "a check driver says nothing" "printed: $out"
fi

# The whole reason stage 3 exists: typecheck's message renders the offending
# expression with lib/expression.phx's `show`, which is only readable because
# the driver runs `show` first.
msg=$("$phx" --quiet "$root/languages/calc/calc-c.phx" \
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
n=$("$phx" --run eval "$root/languages/calc/calc-c.phx" \
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
out=$("$phx" --quiet "$refusals" "$root/tests/sources/one-node.txt" 2>&1)
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
elif "$phx" --quiet "$refusals" "$root/tests/sources/one-node.txt" >/dev/null 2>&1; then
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
lout=$("$phx" --quiet "$lrefusals" "$root/tests/sources/one-node.txt" 2>&1)
lmissing=""
for want in "does not narrow a float" \
            "cannot split on nothing" \
            "writes one to eight bytes, not 9" \
            "writes one to eight bytes, not 0" \
            "a float is four or eight bytes"; do
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
if cnt=$("$root/tests/counts.sh" 2>&1); then
    n=$(printf '%s' "$cnt" | grep -c '^  ok')
    report pass "$n counts in the records match the tree"
else
    report fail "counts in the records match the tree"
    printf '%s\n' "$cnt" | grep '^  FAIL' | sed 's/^/      /' | head -10
fi

# The conformance rule, applied to the page the rule is *about*: the same
# claims, and the same complaints about breaking them, from `phx` and from a
# compiler `phx` wrote.
if "$phx" "$root/tests/grammars/semantics.phx" -o "$tmp0/sem.c" 2>/dev/null \
   && cc -o "$tmp0/semc" "$tmp0/sem.c" 2>/dev/null \
   && "$phx" "$refusals" -o "$tmp0/semr.c" 2>/dev/null \
   && cc -o "$tmp0/semrc" "$tmp0/semr.c" 2>/dev/null; then

    if "$tmp0/semc" "$root/tests/sources/one-node.txt" >/dev/null 2>&1; then
        report pass "and hold in a compiler phx wrote"
    else
        report fail "and hold in a compiler phx wrote"
    fi

    # The library's claims through the same two implementations.
    if "$phx" "$root/tests/grammars/library.phx" -o "$tmp0/lib.c" 2>/dev/null \
       && cc -o "$tmp0/libc" "$tmp0/lib.c" 2>/dev/null \
       && "$tmp0/libc" "$root/tests/sources/one-node.txt" >/dev/null 2>&1; then
        report pass "and the library's do too"
    else
        report fail "and the library's do too"
    fi

    "$phx" --quiet "$refusals" "$root/tests/sources/one-node.txt" 2>"$tmp0/sem-phx" >/dev/null
    "$tmp0/semrc" "$root/tests/sources/one-node.txt" 2>"$tmp0/sem-cc" >/dev/null
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

want=$("$phx" --run eval "$root/languages/calc/calc-c.phx" "$root/languages/calc/programs/sum.calc" 2>/dev/null)
if [ "$want" = "97" ]; then
    report pass "interpreted"
else
    report fail "interpreted" "got '$want', wanted 97"
fi

tmp="$root/build/suite-2"; rm -rf "$tmp"; mkdir -p "$tmp"

# `{ statement }` matched exactly once must still be a list. The `.phx` author
# cannot know how many statements a block will hold, so the grammar decides the
# shape and not the input.
if "$phx" --quiet --run emit-c "$root/languages/calc/calc-c.phx" \
        "$root/languages/calc/tests/one-statement-block.calc" >/dev/null 2>&1; then
    report pass "a block of exactly one statement"
else
    report fail "a block of exactly one statement"
fi

# docs/semantics.md's headline, as a test: Phoenix's division is floored and
# C's truncates, so a language that does not say which it means gets two
# answers from the same program. calc says truncating, in both passes.
neg_i=$("$phx" --run eval "$root/languages/calc/calc-c.phx" \
        "$root/languages/calc/tests/negative-division.calc" 2>/dev/null)
if "$phx" --run emit-c "$root/languages/calc/calc-c.phx" \
        "$root/languages/calc/tests/negative-division.calc" > "$tmp/neg.c" 2>/dev/null \
   && cc -o "$tmp/neg" "$tmp/neg.c" 2>/dev/null; then
    neg_c=$("$tmp/neg")
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
if "$phx" --run emit-c "$root/languages/calc/calc-c.phx" "$root/languages/calc/programs/fizz.calc" \
        > "$tmp/fizz.c" 2>/dev/null \
   && cc -Wall -Werror -o "$tmp/fizz" "$tmp/fizz.c" 2>/dev/null; then
    if ! got=$("$tmp/fizz" 2>&1); then
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

if "$phx" --run emit-c "$root/languages/calc/calc-c.phx" "$root/languages/calc/programs/sum.calc" \
        > "$tmp/out.c" 2>/dev/null \
   && cc -o "$tmp/out" "$tmp/out.c" 2>/dev/null; then
    if ! got=$("$tmp/out" 2>&1); then
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

if "$phx" --run emit-awk "$root/languages/calc/calc-awk.phx" \
        "$root/languages/calc/programs/sum.calc" > "$tmp/sum.awk" 2>/dev/null; then
    got=$(awk -f "$tmp/sum.awk" 2>&1)
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
if "$phx" --run emit-awk "$root/languages/calc/calc-awk.phx" \
        "$root/languages/calc/tests/negative-division.calc" > "$tmp/neg.awk" 2>/dev/null; then
    got=$(awk -f "$tmp/neg.awk" 2>&1)
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
    if ! "$phx" --run emit-awk "$root/languages/calc/calc-awk.phx" "$_prog" \
            > "$tmp/two.awk" 2>/dev/null; then
        report fail "$_what" "the awk backend did not emit"
        return
    fi
    if ! "$phx" --run emit-c "$root/languages/calc/calc-c.phx" "$_prog" \
            > "$tmp/two.c" 2>/dev/null \
       || ! cc -Wall -Werror -o "$tmp/two" "$tmp/two.c" 2>/dev/null; then
        report fail "$_what" "the C backend did not compile cleanly"
        return
    fi
    # Both statuses are checked, and both streams captured, because neither
    # half of that is optional: a program that dies prints nothing, and two
    # programs that both die print the same nothing. COMPLETED.md already has
    # a row for the version of this mistake that reached bench/run.sh.
    if ! _a=$(awk -f "$tmp/two.awk" 2>&1); then
        report fail "$_what" "awk exited nonzero: $(printf '%s' "$_a" | tr '\n' ' ')"
        return
    fi
    if ! _c=$("$tmp/two" 2>&1); then
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
        if "$phx" --run emit-sol "$root/languages/calc/calc-solveig.phx" \
                "$root/languages/calc/programs/sum.calc" > "$tmp/out.sol" 2>/dev/null \
           && "$SOL/bin/solas" "$tmp/out.sol" -o "$tmp/out.sob" >/dev/null 2>&1; then
            got=$("$SOL/bin/solvm" "$tmp/out.sob")
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

if "$phx" "$root/languages/calc/calc-c.phx" -o "$tmp0/calc.c" 2>/dev/null; then
    report pass "calc writes out as C"
else
    report fail "calc writes out as C"
fi

if cc -o "$tmp0/calcc" "$tmp0/calc.c" 2>/dev/null; then
    report pass "one file, no flags, no headers"

    for f in sum fizz logic; do
        "$phx" "$root/languages/calc/calc-c.phx" "$root/languages/calc/programs/$f.calc" \
            > "$tmp0/by-phx" 2>/dev/null
        "$tmp0/calcc" "$root/languages/calc/programs/$f.calc" > "$tmp0/by-cc" 2>/dev/null
        if cmp -s "$tmp0/by-phx" "$tmp0/by-cc"; then
            report pass "$f.calc: identical to phx, byte for byte"
        else
            report fail "$f.calc: identical to phx, byte for byte"
        fi
    done

    # The generated program is a compiler, so what it writes has to compile.
    if "$tmp0/calcc" "$root/languages/calc/programs/fizz.calc" > "$tmp0/fizz.c" 2>/dev/null \
       && cc -Wall -Werror -o "$tmp0/fizz" "$tmp0/fizz.c" 2>/dev/null; then
        if ! got=$("$tmp0/fizz" 2>&1); then
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
    msg=$("$tmp0/calcc" "$root/languages/calc/tests/print-a-bool.calc" 2>&1)
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
if "$phx" "$root/tests/grammars/nul-literal.phx" -o "$tmp0/nul.c" 2>/dev/null \
   && cc -o "$tmp0/nulc" "$tmp0/nul.c" 2>/dev/null; then
    "$phx" --raw "$root/tests/grammars/nul-literal.phx" \
           "$root/tests/sources/with-a-nul.txt" > "$tmp0/nul-phx" 2>/dev/null
    "$tmp0/nulc" --raw "$root/tests/sources/with-a-nul.txt" > "$tmp0/nul-cc" 2>/dev/null
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
if "$phx" "$root/languages/solveig/solveig-sob.phx" -o "$tmp0/sob.c" 2>/dev/null \
   && cc -o "$tmp0/sobc" "$tmp0/sob.c" 2>/dev/null; then
    same=0; differ=0
    for f in "$root"/languages/solveig/tests/conformance/*.sol; do
        "$phx" --raw --driver sob "$root/languages/solveig/solveig-sob.phx" "$f" \
               > "$tmp0/by-phx.sob" 2>/dev/null
        "$tmp0/sobc" --raw --driver sob "$f" > "$tmp0/by-cc.sob" 2>/dev/null
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
if "$phx" "$root/tests/grammars/fold.phx" -o "$tmp0/fold.c" 2>/dev/null \
   && cc -o "$tmp0/foldc" "$tmp0/fold.c" 2>/dev/null; then
    a=$("$phx" --driver folded "$root/tests/grammars/fold.phx" "$arith" 2>/dev/null)
    b=$("$tmp0/foldc" --driver folded "$arith" 2>/dev/null)
    if [ "$a" = "$b" ] && [ "$a" = "15" ]; then
        report pass "a generated compiler runs a rewrite"
    else
        report fail "a generated compiler runs a rewrite" "phx '$a', it '$b'"
    fi
else
    report fail "a generated compiler runs a rewrite" "it did not build"
fi

# An embedded file has to survive the freezing like anything else -- and it is
# the one thing here most likely to hold a byte that does not survive being
# written as a C literal.
if "$phx" "$root/tests/grammars/embed.phx" -o "$tmp0/emb.c" 2>/dev/null \
   && cc -o "$tmp0/embc" "$tmp0/emb.c" 2>/dev/null; then
    "$phx" --raw "$root/tests/grammars/embed.phx" "$root/tests/sources/zero.txt" \
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
if "$phx" "$root/tests/grammars/names.phx" -o "$tmp0/names.c" 2>/dev/null \
   && cc -o "$tmp0/namesc" "$tmp0/names.c" 2>/dev/null; then
    "$phx" "$root/tests/grammars/names.phx" "$root/tests/sources/names.txt" \
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
if "$phx" "$root/tests/grammars/includes.phx" -o "$tmp0/inc.c" 2>/dev/null \
   && cc -o "$tmp0/incc" "$tmp0/inc.c" 2>/dev/null; then
    a=$("$phx" -I "$src/elsewhere" "$root/tests/grammars/includes.phx" \
        "$src/needs-path.inc" 2>/dev/null)
    b=$("$tmp0/incc" -I "$src/elsewhere" "$src/needs-path.inc" 2>/dev/null)
    if [ "$a" = "$b" ] && [ "$a" = "y=8 z=9" ]; then
        report pass "a generated compiler follows an include"
    else
        report fail "a generated compiler follows an include" "phx '$a', it '$b'"
    fi

    # And it says where a node came from, which is the target file's position
    # rather than anything frozen into the tables.
    a=$("$phx" -I "$src/elsewhere" --driver where "$root/tests/grammars/includes.phx" \
        "$src/needs-path.inc" 2>/dev/null)
    b=$("$tmp0/incc" -I "$src/elsewhere" --driver where "$src/needs-path.inc" 2>/dev/null)
    if [ "$a" = "$b" ] && [ "$a" = "$src/elsewhere/far.inc:1 $src/needs-path.inc:2 " ]; then
        report pass "and agrees about where each node came from"
    else
        report fail "and agrees about where each node came from" "phx '$a', it '$b'"
    fi

    missing=$("$tmp0/incc" "$src/absent.inc" 2>&1)
    if printf '%s' "$missing" | grep -qF "cannot read the included file"; then
        report pass "and says so when the file is not there"
    else
        report fail "and says so when the file is not there" "$missing"
    fi
else
    report fail "a generated compiler follows an include" "it did not build"
fi

# Pascal, the same way round.
if "$phx" "$root/languages/pascal/pascal-outline.phx" -o "$tmp0/pascal.c" 2>/dev/null \
   && cc -o "$tmp0/pas" "$tmp0/pascal.c" 2>/dev/null; then
    a=$("$phx" "$root/languages/pascal/pascal-outline.phx" "$root/languages/pascal/tests/grammar/features.pas" 2>/dev/null)
    b=$("$tmp0/pas" "$root/languages/pascal/tests/grammar/features.pas" 2>/dev/null)
    if [ "$a" = "$b" ] && printf '%s' "$b" | grep -qF "packed array [1..80] of char"; then
        report pass "a Pascal compiler, and it agrees with phx"
    else
        report fail "a Pascal compiler, and it agrees with phx"
    fi

    if "$tmp0/pas" "$root/languages/pascal/tests/grammar/unclosed.pas" >/dev/null 2>&1; then
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

if "$phx" "$root/languages/pascal/pascal-c.phx" "$root/languages/pascal/programs/primes.pas" \
        > "$tmp0/primes.c" 2>/dev/null \
   && cc -Wall -Werror -o "$tmp0/primes" "$tmp0/primes.c" 2>/dev/null; then
    report pass "primes.pas compiles to C that cc -Werror accepts"
    # What `fpc -Miso` prints for this program, taken from fpc and kept
    # beside it. The oracle checks the two agree; this checks nothing has
    # drifted since.
    "$tmp0/primes" > "$tmp0/primes.got"
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
if "$phx" "$root/languages/pascal/pascal-c.phx" "$root/languages/pascal/tests/grammar/gcd.pas" \
        > "$tmp0/gcd.c" 2>/dev/null \
   && cc -Wall -Werror -o "$tmp0/gcd" "$tmp0/gcd.c" 2>/dev/null; then
    report pass "gcd.pas compiles to C that cc -Werror accepts"
    "$tmp0/gcd" > "$tmp0/gcd.got"
    if cmp -s "$tmp0/gcd.got" "$root/languages/pascal/tests/grammar/gcd.expected"; then
        report pass "and every line of it is right"
    else
        report fail "and every line of it is right" \
                    "$(printf '%s' "$got" | head -2 | tr '\n' '|')"
    fi
else
    report fail "gcd.pas compiles to C that cc -Werror accepts"
fi

if "$phx" "$root/languages/pascal/pascal-c.phx" -o "$tmp0/pasc.c" 2>/dev/null \
   && cc -o "$tmp0/pasc" "$tmp0/pasc.c" 2>/dev/null; then
    "$tmp0/pasc" "$root/languages/pascal/programs/primes.pas" > "$tmp0/again.c" 2>/dev/null
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
errs=$("$phx" --driver check "$root/languages/pascal/pascal-outline.phx" \
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
errs=$("$phx" --driver check "$root/languages/pascal/pascal.phx" \
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
errs=$("$phx" --driver check "$root/languages/pascal/pascal.phx" "$tmp0/fwd.pas" 2>&1)
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
tree=$("$phx" --tree "$root/languages/pascal/pascal.phx" "$root/languages/pascal/tests/grammar/gcd.pas" 2>/dev/null)
if printf '%s' "$tree" | grep -qE '"[,;()]"'; then
    report fail "the Pascal tree drops its punctuation" \
                "$(printf '%s' "$tree" | grep -oE '"[,;()]"' | head -1) is in it"
else
    report pass "the Pascal tree drops its punctuation"
fi

# A pass over the whole of it, reading something from most of it.
out=$("$phx" "$root/languages/pascal/pascal-outline.phx" "$root/languages/pascal/tests/grammar/features.pas" 2>/dev/null)
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
got=$("$phx" "$root/tests/grammars/attributes.phx" \
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
out=$("$phx" --quiet --tree "$root/languages/pascal/pascal.phx" "$tmp0/deep.pas" 2>&1)
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

if "$phx" --quiet --tree "$root/languages/phx/phoenix.phx" \
        "$root/languages/phx/phoenix.phx" >/dev/null 2>&1; then
    report pass "and parses itself"
else
    report fail "and parses itself"
fi

# Every description in the repository, read by the description of them.
bad=0
for d in "$root"/lib/*.phx "$root"/languages/*/*.phx; do
    "$phx" --quiet --tree "$root/languages/phx/phoenix.phx" "$d" >/dev/null 2>&1 \
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
    n=$("$phx" --quiet "$S/pascal.bnf" "$S/lexical.pas" 2>&1 | grep -c "nothing here matches")
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
    out=$("$phx" --driver c "$root/languages/pascal/pascal-c.phx" "$src" 2>&1 >/dev/null)
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
    if oracle=$("$root/languages/pascal/tests/oracle/run.sh" 2>&1); then
        n=$(printf '%s' "$oracle" | grep -c '^  ok')
        report pass "$n Pascal programs agree with fpc -Miso"
    else
        report fail "Pascal programs agree with fpc -Miso"
        printf '%s\n' "$oracle" | grep -A6 'FAIL' | sed 's/^/        /' | head -14
    fi
else
    skip 1 "the oracle needs fpc, which is not on this machine"
fi

# Solveig's conformance suite: programs and the output each must produce, held
# against `solas` and `solvm`. A suite for the *language* rather than for one
# implementation of it -- see languages/solveig/README.md.
echo "Solveig"
accepts "the description reads" "$root/languages/solveig/solveig.phx"
if rt=$("$root/languages/solveig/tests/roundtrip.sh" 2>&1); then
    n=$(printf '%s' "$rt" | awk '/round-trip to an identical tree/{print $1}')
    report pass "$n Solveig files parse, render, and parse to the same tree"
else
    report fail "Solveig files round-trip" "$(printf '%s' "$rt" | grep -v '^[0-9]' | head -2 | tr '\n' ' ')"
fi

echo "Solveig conformance"
sol=${SOLVEIG:-$root/../Solveig}
if [ -x "$sol/bin/solas" ]; then
    if conf=$("$root/languages/solveig/tests/conformance/run.sh" 2>&1); then
        n=$(printf '%s' "$conf" | grep -c '^  ok')
        report pass "$n Solveig programs conform"
    else
        report fail "Solveig programs conform"
        printf '%s\n' "$conf" | grep -A6 FAIL | sed 's/^/        /' | head -12
    fi
    if bc=$("$root/languages/solveig/tests/bytecode.sh" 2>&1); then
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
    skip 3 "the conformance suite needs Solveig, which is not here"
fi

# Pascal units, which is an experiment rather than a language anybody wants
# compiled: does resolution here need a scope graph? `fpc -Mtp` is the arbiter,
# and it sees real separate units because the runner splits the file back into
# them. languages/units/README.md has the answer.
echo "Pascal units"
accepts "the description reads" "$root/languages/units/units.phx"
if un=$("$root/languages/units/tests/run.sh" 2>&1); then
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
if tut=$("$root/tests/tutorials.sh" 2>&1); then
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
if sa=$("$root/languages/solvm/tests/run.sh" 2>&1); then
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

# **`br` picks its own encoding, and the two walks are pinned separately.**
# `layout` has met no forward label and assumes three bytes; `relax` has
# `layout`'s table and decides both directions against an over-estimate, which
# is the only safe direction -- shrinking one `br` only pulls later addresses
# down, so a `br` that fits against the estimate still fits when everything
# settles. `size` is the first walk's answer and `size2` is the second's.
o="$root/languages/z80/tests/oracle"
prints "a forward br is three bytes in the first walk" "5" \
       --driver code --show size "$root/languages/z80/z80.phx" "$o/short-forward.z80"
prints "and two in the second" "4" \
       --driver code --show size2 "$root/languages/z80/z80.phx" "$o/short-forward.z80"
# The forward jump's size is what decides whether the backward one fits, and
# one extra walk gets both. The arithmetic is in the file, countable by hand.
prints "a chain settles two bytes above the minimum in one walk" "131" \
       --driver code --show size "$root/languages/z80/z80.phx" "$o/chain.z80"
prints "and reaches it in two" "129" \
       --driver code --show size2 "$root/languages/z80/z80.phx" "$o/chain.z80"

# **And the divergence that is left, which is the whole of ROADMAP 2.5.** Two
# forward `br`s, where the second one shrinking in walk two is what brings the
# first into range in walk *three* -- a walk this description does not make.
# One round of one is not a fixpoint, and no fixed number is: every round makes
# the next round's estimate better. 130 here, and 129 is reachable.
prints "a program that needs a third walk does not get one" "130" \
       --driver code --show size2 "$root/languages/z80/z80.phx" \
       "$root/languages/z80/divergent/two-rounds.z80"
if command -v z80asm >/dev/null 2>&1; then
    if za=$("$root/languages/z80/tests/oracle/run.sh" 2>&1); then
        n=$(printf '%s' "$za" | grep -c '^  ok')
        report pass "$n Z80 programs assemble to the bytes z80asm makes, exactly"
    else
        report fail "Z80 programs agree with z80asm"
        printf '%s\n' "$za" | grep -A3 FAIL | sed 's/^/        /' | head -12
    fi
else
    skip 1 "the oracle needs z80asm, which is not on this machine"
fi

# awk: the third language, and the first whose grammar is not vendored -- there
# is no awk grammar on this machine to hold it against, so the oracle carries
# the whole weight. `/usr/bin/awk` is the arbiter of what awk means, and
# `corpus/` is awk that e2fsprogs, ncurses and vim ship.
echo "awk"
accepts "the description reads" "$root/languages/awk/awk.phx"
if rt=$("$root/languages/awk/tests/roundtrip.sh" 2>&1); then
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
    if "$phx" --quiet --driver check "$a" "$f" >/dev/null 2>&1
    then accepted=$((accepted+1))
    else rejected=$((rejected+1)); echo "  check refuses $(basename "$f")"
         "$phx" --quiet --driver check "$a" "$f" 2>&1 | head -2 | sed 's/^/      /'
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

if orc=$("$root/languages/awk/tests/oracle.sh" 2>&1); then
    report pass "$(printf '%s' "$orc" | tail -1)"
else
    report fail "rendered awk does the same thing"
    printf '%s\n' "$orc" | sed 's/^/        /' | head -12
fi

# The conformance rule with a third language under it: awk compiled to C, run,
# and compared with what `/usr/bin/awk` prints on the same input.
if be=$("$root/languages/awk/tests/backend/run.sh" 2>&1); then
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
# The message for `&1` names what may follow the `1`, and has moved three
# times. A subscript was the first way a number becomes the start of a place,
# `&1[a]` being `&(1[a])`, and a member is the second, since `struct`: `&1.x`
# is a place the `types` pass refuses rather than the grammar. So the refusal
# is only certain at the token after the `1`, and names all three.
# `address-of-a-subscripted-number` in the oracle is the program that makes
# the message true.
refuses "the address of something that is not a place" 'expected [, . or ->, and found ";"' \
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
# `struct`. A tag is defined once, at file scope, with at least one member,
# none of them twice and none of them the struct itself; `cc` refuses all of
# those but the empty struct, which it takes as an extension with a size of
# 0, and which is refused here as `int a[0]` is. A pointer to a struct nobody
# defined is C, and `cc` compiles it; it is refused here as outside the
# subset, because the only program that wanted one was a list, and a list
# names its own struct.
#
# Two more are the grammar's, and both are C `cc` compiles: a struct defined
# inside a function, and one with no tag. A tag is written after `struct`
# every time here, and a definition is an item at file scope, so each is a
# syntax error at its `{`.
refuses "a struct defined inside a function" 'expected * or name, and found "{"' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-defined-in-a-function.c"
refuses "and a struct with no tag" 'expected name, and found "{"' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-with-no-tag.c"
refuses "a struct nobody defined" "'struct nope' is not defined" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-undefined.c"
refuses "and a pointer to one" "'struct nope' is not defined" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/struct-pointer-to-undefined.c"
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
refuses "a member of an assignment, assigned" "a member of an assignment is a member of a value" \
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
# Three that `cc` compiles and this subset leaves out, each a refusal rather
# than a wrong answer: a typedef in a block, as a struct is at file scope only;
# a typedef of an array, whose count belongs to a declaration here and not to
# a type; and a pointer to a struct nobody defines, as for a declaration.
refuses "a typedef in a function" 'and found "typedef"' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/typedef-in-a-function.c"
refuses "a typedef of an array" 'expected ;, and found "["' \
        --driver check "$root/languages/c/c-arm64.phx" "$r/typedef-of-an-array.c"
refuses "a typedef of a struct nobody defines" "'struct nope' is not defined" \
        --driver check "$root/languages/c/c-arm64.phx" "$r/typedef-of-an-undefined-struct.c"
if [ "$(uname -m)" = "arm64" ]; then
    if co=$("$root/languages/c/tests/oracle/run.sh" 2>&1); then
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
    if ab=$("$root/languages/c/tests/abi/run.sh" 2>&1); then
        report pass "structs pass between Phoenix's code and cc's, both ways"
    else
        report fail "structs pass between Phoenix's code and cc's, both ways"
        printf '%s\n' "$ab" | grep FAIL | sed 's/^/        /' | head -4
    fi
    # **Programs where the two disagree, pinned rather than fixed**, the way
    # `languages/awk/tests/divergent/` pins the lexical seam. Both come from
    # a type C names with a typedef: `sizeof` is worth a `size_t` and the
    # difference of two pointers a `ptrdiff_t`, eight bytes each under `cc`,
    # and both are an `int` here, since the typedef names a `long` and the
    # subset has none. Both answers
    # are asserted, so closing either gap fails with the old numbers in it.
    dt="$root/build/c-divergent"; rm -rf "$dt"; mkdir -p "$dt"
    diverges() { # what, program, cc's answer, ours
        dv="$root/languages/c/tests/divergent/$2.c"
        if cc -w -o "$dt/want" "$dv" 2>/dev/null \
           && "$phx" --driver arm64 "$root/languages/c/c-arm64.phx" "$dv" \
                  > "$dt/got.s" 2>/dev/null \
           && cc -o "$dt/got" "$dt/got.s" 2>/dev/null; then
            "$dt/want"; want=$?
            "$dt/got";  got=$?
            if [ "$want" = "$3" ] && [ "$got" = "$4" ]; then
                report pass "$1 is $3 to cc and $4 here, as written down"
            else
                report fail "the $2 divergence is the one written down" \
                       "cc says $want and phoenix says $got; divergent/ says $3 and $4"
            fi
        else
            report fail "the $2 divergence compiles on both routes"
        fi
    }
    diverges "sizeof(sizeof(int))" sizeof-of-sizeof 8 4
    diverges "sizeof of a pointer difference" sizeof-a-pointer-difference 8 4
    rm -rf "$dt"
else
    skip 3 "the C oracle and the two divergences need an arm64 cc, and this machine is not arm64"
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
if [ "$skipped" -ne 0 ]; then
    printf '  --    %d skipped, so the records'"'"' own count is not judged here\n' \
           "$skipped"
else
    stale=""
    readme=$(sed -n 's/^make test .*# \([0-9]*\) checks.*/\1/p' \
                 "$root/README.md" | head -1)
    [ "$readme" = "$pass" ] || stale="$stale README.md says $readme."

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
