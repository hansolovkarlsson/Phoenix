#!/bin/sh
# tests/counts.sh -- the numbers in the records, held against the tree that has
# them.
#
# The records make two kinds of claim. The prose kind is already run:
# `tests/grammars/semantics.phx` turns every sentence of docs/semantics.md into
# a check, and the tutorials are executed step by step rather than read. The
# arithmetic kind was run by nobody, and it rots differently -- not by becoming
# wrong when written, but by staying still while the thing it counts moves.
#
# On 2026-09-05 a sweep found nine of these stale. Four had drifted over three
# days, as awk, solvm and solveig each grew after their counts were filed. Two
# were **two hours** old: written that morning, false by lunchtime, by somebody
# who had just measured them. That is the tell. Care does not fix it, because
# care is what wrote them; a check does, which is the argument COMPLETED.md
# already makes about semantics.md:
#
#     A specification nothing runs is a document about a program.
#
# What is deliberately *not* here: the suite's own total. A test that asserts
# how many tests there are changes the answer, and the fixpoint is a puzzle
# rather than a check. tests/run.sh holds that one after its summary line,
# where the number is final and nothing is counting.

set -u

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root" || exit 1
phx=$root/bin/phx

fail=0
ok() { printf '  ok    %s\n' "$1"; }
no() { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }

# The records write a thousand with a comma in it, so the measurement has to.
comma() {
    printf '%s' "$1" | sed -e :a -e 's/\(.*[0-9]\)\([0-9]\{3\}\)/\1,\2/;ta'
}

lines_of() { cat languages/"$1"/*.phx | wc -l | tr -d ' '; }

# A language's node vocabulary is its **own** file's, not a backend's: a
# backend may build nodes the language does not, which is why solveig answers
# 15 here and 22 through solveig-sob.phx. Every directory names that file after
# itself except phx/, whose one description is called phoenix.phx.
nodes_of() {
    f=languages/$1/$1.phx
    [ -f "$f" ] || f=$(ls languages/"$1"/*.phx | head -1)
    "$phx" --nodes "$f" 2>/dev/null | grep -vc '^Position('
}

# ---------------------------------------------------------------------------
# COMPLETED.md's languages table, a row at a time.

for d in pascal solveig awk solvm calc phx; do
    row=$(grep -F "(../languages/$d/)" docs/COMPLETED.md | grep -F '| ' | head -1)
    if [ -z "$row" ]; then
        no "COMPLETED.md has a row for $d/"
        continue
    fi
    cell=$(printf '%s' "$row" | cut -d'|' -f3)

    want=$(comma "$(lines_of "$d")")
    got=$(printf '%s\n' "$cell" | grep -oE '[0-9][0-9,]* lines' | head -1 | sed 's/ lines$//')
    if [ "$got" = "$want" ]; then
        ok "$d/ is $want lines, and COMPLETED.md says so"
    else
        no "$d/ is $want lines, and COMPLETED.md says $got"
    fi

    # phx/'s row quotes no node count, which is the one row that may not.
    got=$(printf '%s\n' "$cell" | grep -oE '[0-9]+ node types' | head -1 | sed 's/ node types$//')
    if [ -n "$got" ]; then
        want=$(nodes_of "$d")
        if [ "$got" = "$want" ]; then
            ok "$d/ has $want node types, and COMPLETED.md says so"
        else
            no "$d/ has $want node types, and COMPLETED.md says $got"
        fi
    fi
done

# ---------------------------------------------------------------------------
# COMPLETED.md's "The tool", which quotes two numbers because the directory
# holds the runtime twice -- once as C and once as the string literal a
# generated compiler is built from.

hand=$(comma "$(cat phoenix/*.c phoenix/phx.h phoenix/reader.h | wc -l | tr -d ' ')")
tool=$(sed -n '/^## The tool$/,/^```$/p' docs/COMPLETED.md)
case $tool in
    *"$hand"*) ok "phoenix/ is $hand hand-written lines, and COMPLETED.md says so" ;;
    *)         no "phoenix/ is $hand hand-written lines; COMPLETED.md does not say that" ;;
esac

if [ -f phoenix/runtime.h ]; then
    gen=$(comma "$(wc -l < phoenix/runtime.h | tr -d ' ')")
    case $tool in
        *"$gen"*) ok "runtime.h is $gen generated lines, and COMPLETED.md says so" ;;
        *)        no "runtime.h is $gen generated lines; COMPLETED.md does not say that" ;;
    esac
else
    printf '  --    runtime.h is not built, so its size cannot be checked\n'
fi

# ---------------------------------------------------------------------------
# postmortem.md quotes the same counts in its opening paragraph. Checked as a
# set of numbers rather than as a sentence, so that rewording the prose does
# not fail a check about arithmetic.

para=$(sed -n '1,25p' docs/postmortem.md)
for d in pascal solveig awk calc phx; do
    want=$(comma "$(lines_of "$d")")
    case $para in
        *"$want"*) ok "postmortem.md's opening has $d/ at $want" ;;
        *)         no "postmortem.md's opening does not have $d/ at $want" ;;
    esac
done

exit $((fail > 0))
