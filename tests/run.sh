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
    what=$1; want=$2; shift 2
    if out=$("$phx" --quiet "$@" 2>&1); then
        report fail "$what" "it was accepted"
    elif printf '%s' "$out" | grep -qF -- "$want"; then
        report pass "$what"
    else
        report fail "$what" "wanted '$want', got: $(printf '%s' "$out" | head -1)"
    fi
}

# warns <what> <expected text> <args...>
warns() {
    what=$1; want=$2; shift 2
    out=$("$phx" --quiet "$@" 2>&1)
    if printf '%s' "$out" | grep -qF -- "$want"; then
        report pass "$what"
    else
        report fail "$what" "no warning matching '$want'"
    fi
}

echo "grammars it should accept"
accepts "calc.phx"                  "$root/examples/calc.phx"
accepts "an empty production"       "$root/tests/grammars/empty-production.phx"

echo "grammars it should refuse"
refuses "left recursion"    "left-recursive"   "$root/tests/grammars/left-recursion.phx"
refuses "an unknown rule"   "not a rule"       "$root/tests/grammars/unknown-rule.phx"
refuses "a range over tokens" "asks about characters" "$root/tests/grammars/range-in-syntax.phx"
refuses "no syntactic half" "no syntactic rules" "$root/tests/grammars/no-syntax.phx"
refuses "a literal nothing spells" "no token rule spells" "$root/tests/grammars/unspellable.phx"

echo "grammars it should warn about"
warns "alternatives in the wrong order" "will always win" "$root/tests/grammars/order.phx"
warns "a fragment not declared one"     "%fragment"       "$root/tests/grammars/fragment-forgotten.phx"

echo "actions"
accepts "actions on calc.phx"   "$root/examples/calc.phx"
accepts "a spread into a list"  "$root/tests/grammars/spread.phx"
refuses "a \$n past the last factor" "but this alternative" \
        "$root/tests/grammars/ref-out-of-range.phx"
refuses "a label nothing carries"    "is named" \
        "$root/tests/grammars/unknown-label.phx"
warns   "one node type, two shapes"  "elsewhere with" \
        "$root/tests/grammars/inconsistent-node.phx"

# The vocabulary a pass will be written against.
nodes=$("$phx" --nodes "$root/examples/calc.phx" 2>/dev/null)
if printf '%s' "$nodes" | grep -q "^Binary(op, left, right)$"; then
    report pass "--nodes lists the vocabulary"
else
    report fail "--nodes lists the vocabulary" "got: $(printf '%s' "$nodes" | tr '\n' ' ')"
fi

echo "sources"
accepts "sum.calc"        "$root/examples/calc.phx" "$root/examples/sum.calc"
accepts "one.calc"        "$root/examples/calc.phx" "$root/tests/sources/one.calc"
accepts "an empty tail"   "$root/tests/grammars/empty-production.phx" "$root/tests/sources/list.txt"
accepts "a spread over a file" "$root/tests/grammars/spread.phx" "$root/tests/sources/list.txt"

# The whole point of stage 1: `width * height - 1` must come out left-leaning,
# with precedence from the grammar and associativity from the fold. A `-` whose
# left is a `Binary` and whose right is a `Number` is that shape and no other.
tree=$("$phx" "$root/examples/calc.phx" "$root/examples/sum.calc" 2>/dev/null)
if printf '%s' "$tree" | grep -q "op: \"-\"" \
   && printf '%s' "$tree" | grep -q "left: Binary" \
   && ! printf '%s' "$tree" | grep -q "expression"; then
    report pass "the fold associates to the left"
else
    report fail "the fold associates to the left"
fi
refuses "a reserved word as a name" "expected"  "$root/examples/calc.phx" "$root/tests/sources/reserved.calc"
refuses "a character no rule matches" "nothing here matches" \
        "$root/examples/calc.phx" "$root/tests/sources/bad-token.calc"

# Solveig's Pascal grammar, when it is there: the strongest evidence available
# that this reads a real published grammar and not just its own examples. Both
# files it accepts are accepted by `fpc -Miso`.
S=/Users/hans/Projects/Solveig/programs/check_syntax
if [ -d "$S" ]; then
    echo "Solveig's pascal.bnf"
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
