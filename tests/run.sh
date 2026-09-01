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
refuses "a fold with nothing to fold onto" "nothing to fold onto" \
        "$root/tests/grammars/fold-in-action.phx"

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
tree=$("$phx" --tree "$root/examples/calc-c.phx" "$root/examples/sum.calc" 2>/dev/null)
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

echo "drivers"
refuses "a driver in the wrong order" "nothing before it defines one" \
        "$root/tests/grammars/misordered-driver.phx"
refuses "a driver naming no such pass" "there is no such pass" \
        "$root/tests/grammars/no-such-pass.phx"
refuses "a driver answering with nothing" "none of its passes defines one" \
        "$root/tests/grammars/driver-no-answer.phx"
refuses "two drivers of one name" "two drivers called" \
        "$root/tests/grammars/duplicate-driver.phx"

# The default driver is the first declared, and it compiles.
if "$phx" --quiet "$root/examples/calc-c.phx" "$root/examples/sum.calc" \
        > /dev/null 2>&1; then
    report pass "the default driver runs"
else
    report fail "the default driver runs"
fi

# A driver with no `->` is a validation run: it says nothing and answers with
# its status.
out=$("$phx" --driver check "$root/examples/calc-c.phx" \
        "$root/examples/fizz.calc" 2>&1)
if [ -z "$out" ]; then
    report pass "a check driver says nothing"
else
    report fail "a check driver says nothing" "printed: $out"
fi

# The whole reason stage 3 exists: typecheck's message renders the offending
# expression with lib/expression.phx's `show`, which is only readable because
# the driver runs `show` first.
msg=$("$phx" --quiet "$root/examples/calc-c.phx" \
        "$root/tests/sources/print-a-bool.calc" 2>&1)
if printf '%s' "$msg" | grep -qF "(n < 2) is bool"; then
    report pass "a pass reading another pass's work"
else
    report fail "a pass reading another pass's work" "$(printf '%s' "$msg" | head -1)"
fi

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

# ---------------------------------------------------------------------------
# A description written out as its own compiler. The property being checked is
# not that it works -- it is that it is **the same**: the generated program runs
# the same matcher and evaluator phx runs, over frozen tables, so a byte of
# difference between them would mean two implementations had appeared.

echo "generated compilers"

if "$phx" "$root/examples/calc-c.phx" -o "$tmp0/calc.c" 2>/dev/null; then
    report pass "calc writes out as C"
else
    report fail "calc writes out as C"
fi

if cc -o "$tmp0/calcc" "$tmp0/calc.c" 2>/dev/null; then
    report pass "one file, no flags, no headers"

    for f in sum fizz logic; do
        "$phx" "$root/examples/calc-c.phx" "$root/examples/$f.calc" \
            > "$tmp0/by-phx" 2>/dev/null
        "$tmp0/calcc" "$root/examples/$f.calc" > "$tmp0/by-cc" 2>/dev/null
        if cmp -s "$tmp0/by-phx" "$tmp0/by-cc"; then
            report pass "$f.calc: identical to phx, byte for byte"
        else
            report fail "$f.calc: identical to phx, byte for byte"
        fi
    done

    # The generated program is a compiler, so what it writes has to compile.
    if "$tmp0/calcc" "$root/examples/fizz.calc" > "$tmp0/fizz.c" 2>/dev/null \
       && cc -Wall -Werror -o "$tmp0/fizz" "$tmp0/fizz.c" 2>/dev/null; then
        got=$("$tmp0/fizz" | tr '\n' ' ')
        if [ "$got" = "1 2 300 4 5 300 7 8 300 10 11 300 13 14 300 " ]; then
            report pass "and what it writes runs"
        else
            report fail "and what it writes runs" "got: $got"
        fi
    else
        report fail "and what it writes runs" "it did not compile"
    fi

    # Diagnostics still point into the description, from a program the
    # description is no longer beside.
    msg=$("$tmp0/calcc" "$root/tests/sources/print-a-bool.calc" 2>&1)
    if printf '%s' "$msg" | grep -qF "(n < 2) is bool"; then
        report pass "its diagnostics survive the freezing"
    else
        report fail "its diagnostics survive the freezing" "$msg"
    fi
else
    report fail "one file, no flags, no headers" "it did not compile"
fi

# Pascal, the same way round.
if "$phx" "$root/examples/pascal-outline.phx" -o "$tmp0/pascal.c" 2>/dev/null \
   && cc -o "$tmp0/pas" "$tmp0/pascal.c" 2>/dev/null; then
    a=$("$phx" "$root/examples/pascal-outline.phx" "$root/tests/pascal/features.pas" 2>/dev/null)
    b=$("$tmp0/pas" "$root/tests/pascal/features.pas" 2>/dev/null)
    if [ "$a" = "$b" ] && printf '%s' "$b" | grep -qF "packed array [1..80] of char"; then
        report pass "a Pascal compiler, and it agrees with phx"
    else
        report fail "a Pascal compiler, and it agrees with phx"
    fi

    if "$tmp0/pas" "$root/tests/pascal/unclosed.pas" >/dev/null 2>&1; then
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

if "$phx" "$root/examples/pascal-c.phx" "$root/examples/primes.pas" \
        > "$tmp0/primes.c" 2>/dev/null \
   && cc -Wall -Werror -o "$tmp0/primes" "$tmp0/primes.c" 2>/dev/null; then
    report pass "primes.pas compiles to C that cc -Werror accepts"
    # What `fpc -Miso` prints for this program, taken from fpc and kept
    # beside it. The oracle checks the two agree; this checks nothing has
    # drifted since.
    "$tmp0/primes" > "$tmp0/primes.got"
    if cmp -s "$tmp0/primes.got" "$root/examples/primes.expected"; then
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
if "$phx" "$root/examples/pascal-c.phx" "$root/tests/pascal/gcd.pas" \
        > "$tmp0/gcd.c" 2>/dev/null \
   && cc -Wall -Werror -o "$tmp0/gcd" "$tmp0/gcd.c" 2>/dev/null; then
    report pass "gcd.pas compiles to C that cc -Werror accepts"
    "$tmp0/gcd" > "$tmp0/gcd.got"
    if cmp -s "$tmp0/gcd.got" "$root/tests/pascal/gcd.expected"; then
        report pass "and every line of it is right"
    else
        report fail "and every line of it is right" \
                    "$(printf '%s' "$got" | head -2 | tr '\n' '|')"
    fi
else
    report fail "gcd.pas compiles to C that cc -Werror accepts"
fi

if "$phx" "$root/examples/pascal-c.phx" -o "$tmp0/pasc.c" 2>/dev/null \
   && cc -o "$tmp0/pasc" "$tmp0/pasc.c" 2>/dev/null; then
    "$tmp0/pasc" "$root/examples/primes.pas" > "$tmp0/again.c" 2>/dev/null
    if cmp -s "$tmp0/again.c" "$tmp0/primes.c"; then
        report pass "a standalone Pascal-to-C compiler, agreeing with phx"
    else
        report fail "a standalone Pascal-to-C compiler, agreeing with phx"
    fi
else
    report fail "a standalone Pascal-to-C compiler, agreeing with phx" "it did not build"
fi

echo "Pascal, with actions"
accepts "the description reads" "$root/examples/pascal.phx"
accepts "the outline description reads" "$root/examples/pascal-outline.phx"

# Two real Pascal programs, checked. A checker that invents an error on a
# correct program is the worst thing it could do, so this comes first.
for f in gcd features; do
    accepts "$f.pas checks clean" --driver check \
            "$root/examples/pascal-outline.phx" "$root/tests/pascal/$f.pas"
done

# And one that is wrong in four ways, each of which has to be found.
errs=$("$phx" --driver check "$root/examples/pascal-outline.phx" \
        "$root/tests/pascal/type-errors.pas" 2>&1)
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
errs=$("$phx" --driver check "$root/examples/pascal.phx" \
        "$root/tests/pascal/with-fields.pas" 2>&1)
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
    "$root/tests/pascal/features.pas" > "$tmp0/fwd.pas"
errs=$("$phx" --driver check "$root/examples/pascal.phx" "$tmp0/fwd.pas" 2>&1)
if printf '%s' "$errs" | grep -qF "'rr' is not declared" \
   && ! printf '%s' "$errs" | grep -qF "'r' is not declared"; then
    report pass "a forward heading's parameters"
else
    report fail "a forward heading's parameters" "$(printf '%s' "$errs" | head -1)"
fi

for f in gcd features; do
    accepts "$f.pas builds a tree" --tree "$root/examples/pascal.phx" \
            "$root/tests/pascal/$f.pas"
done
for f in keyword missing-semicolon unclosed; do
    refuses "$f.pas is still refused" "error" --tree \
            "$root/examples/pascal.phx" "$root/tests/pascal/$f.pas"
done

# The tree has to be abstract, not a parse tree wearing node names: no
# punctuation, and no wrapper node holding nothing.
tree=$("$phx" --tree "$root/examples/pascal.phx" "$root/tests/pascal/gcd.pas" 2>/dev/null)
if printf '%s' "$tree" | grep -qE '"[,;()]"'; then
    report fail "the Pascal tree drops its punctuation" \
                "$(printf '%s' "$tree" | grep -oE '"[,;()]"' | head -1) is in it"
else
    report pass "the Pascal tree drops its punctuation"
fi

# A pass over the whole of it, reading something from most of it.
out=$("$phx" "$root/examples/pascal-outline.phx" "$root/tests/pascal/features.pas" 2>/dev/null)
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

# Wirth's Pascal, vendored into tests/pascal -- the strongest evidence that
# this reads a real published grammar and not only its own examples. Both files
# it accepts are accepted by `fpc -Miso`. See tests/pascal/README.md for why
# these are copies.
S="$root/tests/pascal"
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
out=$("$phx" --quiet --tree "$root/examples/pascal.phx" "$tmp0/deep.pas" 2>&1)
code=$?
if [ "$code" -ge 128 ]; then
    report fail "deep nesting is refused, not fatal" "died with signal $((code - 128))"
elif printf '%s' "$out" | grep -qF "nested too deeply"; then
    report pass "deep nesting is refused, not fatal"
else
    report fail "deep nesting is refused, not fatal" "$(printf '%s' "$out" | head -1)"
fi

echo "the notation, in itself"
accepts "phoenix.phx reads" "$root/examples/phoenix.phx"

if "$phx" --quiet --tree "$root/examples/phoenix.phx" \
        "$root/examples/phoenix.phx" >/dev/null 2>&1; then
    report pass "and parses itself"
else
    report fail "and parses itself"
fi

# Every description in the repository, read by the description of them.
bad=0
for d in "$root"/lib/*.phx "$root"/examples/*.phx; do
    "$phx" --quiet --tree "$root/examples/phoenix.phx" "$d" >/dev/null 2>&1 \
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
# The oracle. Every program in tests/oracle is compiled by `fpc -Miso` and by
# Phoenix, and the two must write the same bytes. fpc has been read by more
# people than this repository has, so where they differ Phoenix is wrong until
# somebody shows otherwise.
#
# Skipped and not failed without fpc: it is an oracle, not a dependency.

echo "the oracle"
if command -v fpc >/dev/null 2>&1; then
    if oracle=$("$root/tests/oracle/run.sh" 2>&1); then
        n=$(printf '%s' "$oracle" | grep -c '^  ok')
        report pass "$n Pascal programs agree with fpc -Miso"
    else
        report fail "Pascal programs agree with fpc -Miso"
        printf '%s\n' "$oracle" | grep -A6 'FAIL' | sed 's/^/        /' | head -14
    fi
else
    printf '  --    the oracle needs fpc, which is not on this machine\n'
fi

echo
printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
