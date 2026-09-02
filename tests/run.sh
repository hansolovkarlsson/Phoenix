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
refuses "a reserved word as a name" "expected"  "$root/languages/calc/calc-c.phx" "$root/languages/calc/tests/reserved.calc"
refuses "a character no rule matches" "nothing here matches" \
        "$root/languages/calc/calc-c.phx" "$root/languages/calc/tests/bad-token.calc"

echo "what a source includes"
# `%include` is `%import` one level down: for the language being described
# rather than for the description. It cannot be a pass -- a pass walks one tree
# that has already been read -- so it is a directive the reader acts on, and
# these are the four new ways a reader that follows files can fail.
inc="$root/tests/grammars/includes.phx"
src="$root/tests/sources/includes"

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
        --run eval "$root/languages/calc/calc-c.phx" "$root/languages/calc/programs/fizz.calc"

if "$phx" --run emit-c "$root/languages/calc/calc-c.phx" "$root/languages/calc/programs/sum.calc" \
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
    printf '  --    the oracle needs fpc, which is not on this machine\n'
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
        report pass "$(printf '%s' "$bc" | tail -1)"
    else
        report fail "the .sob backend agrees with solas"
        printf '%s\n' "$bc" | sed 's/^/        /' | head -14
    fi
else
    printf '  --    the conformance suite needs Solveig, which is not here\n'
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

echo
printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
