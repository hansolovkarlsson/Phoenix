#!/bin/sh
# languages/solvm/tests/tutorial.sh -- run the tutorial and hold the document
# to what actually happens.
#
# Every step below builds the file `tutorial.md` says to build, runs the
# command it says to run, and then checks that **the output it got appears in
# the document**. So a pasted output that drifts from the real one fails here
# rather than misleading somebody following along.
#
# That last part is the point. The first version of this page had four defects
# a careful read did not find: a `solvm` invoked on bytecode nothing had
# assembled, three places where the source had changed and the reader would
# have run the previous build, a caret line two spaces short, and a final
# comparison against a Solveig program that no longer said the same thing.
#
# Needs a Solveig checkout to run anything; without one it reports itself
# skipped.

set -u

root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
doc=$root/languages/solvm/tutorial.md
asm=$root/languages/solvm/solvm-sob.phx
phx=$root/bin/phx
sol=${SOLVEIG:-$root/../Solveig}

fail=0
tmp=${TMPDIR:-/tmp}/solvm-tutorial.$$
mkdir -p "$tmp" || exit 1
trap 'rm -rf "$tmp"' EXIT
cd "$tmp" || exit 1

# Does the document contain, verbatim, what the command just printed?
says() {
    printf '%s' "$2" > got
    if python3 -c "import sys; sys.exit(0 if open('got').read().strip() in open(sys.argv[1]).read() else 1)" "$doc"; then
        printf '  ok    %s\n' "$1"
    else
        printf '  FAIL  %s -- the page does not say this:\n' "$1"
        printf '%s\n' "$2" | sed 's/^/        /'
        fail=1
    fi
}

if [ ! -x "$sol/bin/solvm" ] || [ ! -x "$sol/bin/solas" ]; then
    printf '  --    the tutorial needs a Solveig checkout, which is not here\n'
    exit 0
fi
solvm=$sol/bin/solvm
solas=$sol/bin/solas

# ---- 1. a send ----------------------------------------------------------
cat > sum.sasm <<'X'
.slots 1
        const   #2
        const   #40
        send    add, 1
        send    display, 0
        pop
        halt
X
"$phx" --raw "$asm" sum.sasm > sum.sob
says "1  a send answers 42" "$("$solvm" sum.sob 2>&1)"

# ---- 1b. and the same with an argument missing --------------------------
cat > sum.sasm <<'X'
.slots 1
        const   #2
        send    add, 1
        send    display, 0
        pop
        halt
X
"$phx" --raw "$asm" sum.sasm > sum.sob
says "1b a missing argument" "$("$solvm" sum.sob 2>&1)"

# ---- 2. the argument back, the pop gone ---------------------------------
cat > sum.sasm <<'X'
.slots 1
        const   #2
        const   #40
        send    add, 1
        send    display, 0
        halt
X
"$phx" --raw "$asm" sum.sasm > sum.sob
says "2  a missing pop at halt is accepted" "$("$solvm" sum.sob 2>&1)"

# ---- 4. the loop --------------------------------------------------------
cat > sum.sasm <<'X'
.slots 1
        const   #0
        setglob total
        pop
        const   #1
        setglob i
        pop
top:
        global  i
        const   #6
        send    lessThan, 1
        exitf   done
        global  total
        global  i
        send    add, 1
        setglob total
        pop
        global  i
        const   #1
        send    add, 1
        setglob i
        pop
        loop    top
done:
        nil
        pop
        global  total
        send    display, 0
        pop
        halt
X
cp sum.sasm loop.sasm
"$phx" --raw "$asm" sum.sasm > sum.sob
says "4  the loop sums to 15" "$("$solvm" sum.sob 2>&1)"

# ---- 4b. written as a forward jump --------------------------------------
sed 's/^        loop    top$/        jump    top/' loop.sasm > sum.sasm
says "4b a backward jump is named" "$("$phx" --driver check "$asm" sum.sasm 2>&1)"
cp loop.sasm sum.sasm

# ---- 5. arms that do not balance ----------------------------------------
cat > t.sasm <<'X'
.slots 1
        global  true
        jumpf   otherwise, ifTrue
        string  "yes"
otherwise:
        send    display, 0
        pop
        halt
X
"$phx" --raw "$asm" t.sasm > t.sob
says "5  unbalanced arms are refused" "$("$solvm" t.sob 2>&1)"

cat > t.sasm <<'X'
.slots 1
        global  true
        jumpf   otherwise, ifTrue
        string  "yes"
        jump    endif
otherwise:
        nil
endif:
        send    display, 0
        pop
        halt
X
"$phx" --raw "$asm" t.sasm > t.sob
says "5b and balanced ones run" "$("$solvm" t.sob 2>&1)"

# ---- 6. a block ---------------------------------------------------------
cat > sum.sasm <<'X'
.slots 1
        const   #0
        setglob total
        pop
        const   #1
        setglob i
        pop
top:
        global  i
        const   #6
        send    lessThan, 1
        exitf   done
        global  total
        global  i
        send    add, 1
        setglob total
        pop
        global  i
        const   #1
        send    add, 1
        setglob i
        pop
        loop    top
done:
        nil
        pop
        block   twice
        global  total
        send    value, 1
        send    display, 0
        pop
        halt

.block twice arity 1 slots 2
        local   1
        local   1
        send    add, 1
        return
.end
X
"$phx" --raw "$asm" sum.sasm > sum.sob
says "6  the block doubles it" "$("$solvm" sum.sob 2>&1)"
says "6b the tail of the dump" "$("$solvm" --dump sum.sob 2>&1 | tail -6)"

# ---- 6c. the same block, with its frame named ---------------------------
#
# Only the block changes, which is what the page says to change. It claims
# three things: it still prints 30, the disassembly is unchanged because
# `local n` *is* `local 1`, and `--trace` now names the argument.
#
# `sum.sob` is left holding this build on purpose, so step 7 compares the
# **named** spelling against solas -- which is the claim that naming a slot
# changes nothing that reaches the machine.

sed -e 's/^\.block twice arity 1 slots 2$/.block twice arity 1 slots self, n/' \
    -e 's/^        local   1$/        local   n/' sum.sasm > named.sasm
mv named.sasm sum.sasm

"$phx" --raw "$asm" sum.sasm > sum.sob
says "6c named, and it still doubles it" "$("$solvm" sum.sob 2>&1)"
says "6d the same dump, because it is the same byte" \
     "$("$solvm" --dump sum.sob 2>&1 | tail -6)"
says "6e and --trace names the argument" \
     "$("$solvm" --trace sum.sob 2>&1 | tail -3)"

# ---- 7. and it is what solas emits --------------------------------------
cat > sum.sol <<'X'
total := #0.
i := #1.
{ i:lessThan(#6) }:whileTrue({
  total := total:add(i).
  i := i:add(#1)
}).
{ n | n:add(n) }:value(total):display.
X
"$solas" sum.sol -o solas.sob >/dev/null 2>&1
says "7  solas prints the same" "$("$solvm" solas.sob 2>&1)"

norm() {
    "$solvm" --dump "$1" 2>/dev/null \
      | sed -E -e 's/^== .* ==$/== chunk ==/' \
               -e 's/^([0-9]{4})[[:space:]]+([0-9]+|\|)[[:space:]]/\1 /'
}
norm solas.sob > a ; norm sum.sob > b
if cmp -s a b; then
    printf '  ok    7b identical instruction streams, as the page claims\n'
else
    printf '  FAIL  7b the page claims these are identical\n'
    diff a b | sed 's/^/        /' | head -12
    fail=1
fi

[ "$fail" -eq 0 ]
