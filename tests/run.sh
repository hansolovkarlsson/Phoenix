#!/bin/sh
# tests/run.sh -- what Phoenix is expected to do, and what it is expected to
# refuse. Run from the repository root, or by `make test`.

set -u

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
phx="$root/bin/phx"
pass=0
fail=0

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
accepts "calc.phx"                  "$root/examples/calc-c.phx"
accepts "an empty production"       "$root/tests/grammars/empty-production.phx"

echo "grammars it should refuse"
refuses "left recursion"    "left-recursive"   "$root/tests/grammars/left-recursion.phx"
refuses "an unknown rule"   "not a rule"       "$root/tests/grammars/unknown-rule.phx"
refuses "a range over tokens" "asks about characters" "$root/tests/grammars/range-in-syntax.phx"
refuses "no syntactic half, asked to parse" "no syntactic rules" \
        "$root/tests/grammars/no-syntax.phx" "$root/tests/sources/one.calc"
accepts "no syntactic half, on its own" "$root/tests/grammars/no-syntax.phx"
refuses "a literal nothing spells" "no token rule spells" "$root/tests/grammars/unspellable.phx"
refuses "a clause nothing can reach" "can never match" \
        "$root/tests/grammars/unreachable-clause.phx"

echo "grammars it should warn about"
warns "alternatives in the wrong order" "will always win" "$root/tests/grammars/order.phx"
warns "a fragment not declared one"     "%fragment"       "$root/tests/grammars/fragment-forgotten.phx"

tmp0=$(mktemp -d)
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
if "$phx" --run emit-c "$root/examples/calc-c.phx" "$root/examples/logic.calc" \
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
accepts "a description in three files" "$root/examples/calc-c.phx"
accepts "modules that import each other" "$root/tests/grammars/circular-a.phx"
refuses "a rule defined in two files" "already defined" \
        "$root/tests/grammars/duplicate-rule.phx"
refuses "an import that is not there" "cannot read" \
        "$root/tests/grammars/missing-import.phx"

# A file named twice is read once, so the joined text holds one copy.
# calc-c imports calc, which imports lexical and expression: four, each once.
listed=$("$phx" --imports "$root/examples/calc-c.phx" 2>/dev/null)
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
accepts "actions on calc.phx"   "$root/examples/calc-c.phx"
accepts "a spread into a list"  "$root/tests/grammars/spread.phx"
refuses "a \$n past the last factor" "but this alternative" \
        "$root/tests/grammars/ref-out-of-range.phx"
refuses "a label nothing carries"    "is named" \
        "$root/tests/grammars/unknown-label.phx"
warns   "one node type, two shapes"  "elsewhere with" \
        "$root/tests/grammars/inconsistent-node.phx"

# The vocabulary a pass will be written against.
nodes=$("$phx" --nodes "$root/examples/calc-c.phx" 2>/dev/null)
if printf '%s' "$nodes" | grep -q "^Binary(op, left, right)$"; then
    report pass "--nodes lists the vocabulary"
else
    report fail "--nodes lists the vocabulary" "got: $(printf '%s' "$nodes" | tr '\n' ' ')"
fi

echo "sources"
accepts "sum.calc"        "$root/examples/calc-c.phx" "$root/examples/sum.calc"
accepts "one.calc"        "$root/examples/calc-c.phx" "$root/tests/sources/one.calc"
accepts "an empty tail"   "$root/tests/grammars/empty-production.phx" "$root/tests/sources/list.txt"
accepts "a spread over a file" "$root/tests/grammars/spread.phx" "$root/tests/sources/list.txt"

# The whole point of stage 1: `width * height - 1` must come out left-leaning,
# with precedence from the grammar and associativity from the fold. A `-` whose
# left is a `Binary` and whose right is a `Number` is that shape and no other.
tree=$("$phx" "$root/examples/calc-c.phx" "$root/examples/sum.calc" 2>/dev/null)
if printf '%s' "$tree" | grep -q "op: \"-\"" \
   && printf '%s' "$tree" | grep -q "left: Binary" \
   && ! printf '%s' "$tree" | grep -q "expression"; then
    report pass "the fold associates to the left"
else
    report fail "the fold associates to the left"
fi
refuses "a reserved word as a name" "expected"  "$root/examples/calc-c.phx" "$root/tests/sources/reserved.calc"
refuses "a character no rule matches" "nothing here matches" \
        "$root/examples/calc-c.phx" "$root/tests/sources/bad-token.calc"

echo "passes"
accepts "the calculator's passes" "$root/examples/calc-c.phx"
accepts "typecheck accepts fizz"  --run typecheck --show type \
        "$root/examples/calc-c.phx" "$root/examples/fizz.calc"
refuses "an int used as a condition" "wants a bool" --run typecheck --show type \
        "$root/examples/calc-c.phx" "$root/tests/sources/int-as-condition.calc"
refuses "printing a bool" "print wants an int" --run typecheck --show type \
        "$root/examples/calc-c.phx" "$root/tests/sources/print-a-bool.calc"
refuses "an undefined name"  "is not defined" \
        --run eval "$root/examples/calc-c.phx" "$root/tests/sources/undefined.calc"
refuses "division by zero"   "division by zero" \
        --run eval "$root/examples/calc-c.phx" "$root/tests/sources/divzero.calc"

# One mistake should produce one message. The cascade this guards against --
# a check firing, then the arithmetic above it complaining about the nil it
# left, then every node above that -- is what `checks are guards` is for.
n=$("$phx" --run eval "$root/examples/calc-c.phx" \
        "$root/tests/sources/undefined.calc" 2>&1 | grep -c "error:")
if [ "$n" -eq 1 ]; then
    report pass "one mistake, one message"
else
    report fail "one mistake, one message" "got $n errors, wanted 1"
fi

# ---------------------------------------------------------------------------
# The conformance rule from docs/semantics.md, made a test rather than a hope:
# one .phx, interpreted and through both backends, must give the same answer.

want=$("$phx" --run eval "$root/examples/calc-c.phx" "$root/examples/sum.calc" 2>/dev/null)
if [ "$want" = "97" ]; then
    report pass "interpreted"
else
    report fail "interpreted" "got '$want', wanted 97"
fi

tmp=$(mktemp -d)

# `{ statement }` matched exactly once must still be a list. The `.phx` author
# cannot know how many statements a block will hold, so the grammar decides the
# shape and not the input.
if "$phx" --quiet --run emit-c "$root/examples/calc-c.phx" \
        "$root/tests/sources/one-statement-block.calc" >/dev/null 2>&1; then
    report pass "a block of exactly one statement"
else
    report fail "a block of exactly one statement"
fi

# docs/semantics.md's headline, as a test: Phoenix's division is floored and
# C's truncates, so a language that does not say which it means gets two
# answers from the same program. calc says truncating, in both passes.
neg_i=$("$phx" --run eval "$root/examples/calc-c.phx" \
        "$root/tests/sources/negative-division.calc" 2>/dev/null)
if "$phx" --run emit-c "$root/examples/calc-c.phx" \
        "$root/tests/sources/negative-division.calc" > "$tmp/neg.c" 2>/dev/null \
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
if "$phx" --run emit-c "$root/examples/calc-c.phx" "$root/examples/fizz.calc" \
        > "$tmp/fizz.c" 2>/dev/null \
   && cc -Wall -Werror -o "$tmp/fizz" "$tmp/fizz.c" 2>/dev/null; then
    got=$("$tmp/fizz" | tr '\n' ' ')
    if [ "$got" = "1 2 300 4 5 300 7 8 300 10 11 300 13 14 300 " ]; then
        report pass "a loop and a branch, compiled and run"
    else
        report fail "a loop and a branch, compiled and run" "got: $got"
    fi
else
    report fail "a loop and a branch, compiled and run" "it did not compile cleanly"
fi

# The interpreter's boundary, said out loud rather than failing obscurely.
refuses "a loop refuses to be interpreted" "cannot be interpreted" \
        --run eval "$root/examples/calc-c.phx" "$root/examples/fizz.calc"

if "$phx" --run emit-c "$root/examples/calc-c.phx" "$root/examples/sum.calc" \
        > "$tmp/out.c" 2>/dev/null \
   && cc -o "$tmp/out" "$tmp/out.c" 2>/dev/null; then
    got=$("$tmp/out")
    if [ "$got" = "$want" ]; then
        report pass "through the C backend, same answer"
    else
        report fail "through the C backend, same answer" "got '$got', wanted '$want'"
    fi
else
    report fail "through the C backend, same answer" "it did not compile"
fi

# The Solveig backend is parked. Its example is still read, so the notation
# cannot drift out from under it -- but nothing runs `solas`, and the round
# trip happens only when it is asked for by name:
#
#     PHX_TEST_SOLVEIG=1 make test
#
# Auto-detecting a sibling checkout is how a test suite comes to fail for
# reasons that have nothing to do with the project it is testing.
accepts "the parked Solveig example" "$root/examples/calc-solveig.phx"

if [ -n "${PHX_TEST_SOLVEIG:-}" ]; then
    SOL=${SOLVEIG:-/Users/hans/Projects/Solveig}
    if [ -x "$SOL/bin/solas" ]; then
        if "$phx" --run emit-sol "$root/examples/calc-solveig.phx" \
                "$root/examples/sum.calc" > "$tmp/out.sol" 2>/dev/null \
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

# Wirth's Pascal, vendored into tests/pascal -- the strongest evidence that
# this reads a real published grammar and not only its own examples. Both files
# it accepts are accepted by `fpc -Miso`. See tests/pascal/README.md for why
# these are copies.
S="$root/tests/pascal"
if [ -d "$S" ]; then
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

echo
printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
