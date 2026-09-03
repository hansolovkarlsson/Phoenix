#!/bin/sh
# languages/solvm/tests/run.sh -- what the assembler is expected to do.
#
# Four things, and the first three need nothing outside this repository:
#
#   1. every program assembles to bytes identical to the golden beside it,
#      which is what catches drift without SolVM being here at all;
#   2. every program renders back out and re-parses to the same tree;
#   3. every file in tests/ is refused, with the message it is refused for;
#   4. and where a Solveig checkout is to hand, every program is run under
#      `solvm` and held against the same program written in Solveig and
#      compiled by `solas` -- both what it prints and, instruction by
#      instruction, what it compiled to.
#
# Run from anywhere. `REGOLD=1` rewrites the goldens, which is what to do
# after SolVM's format version rises.

set -u

root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
cd "$root" || exit 1

phx=$root/bin/phx
lang=languages/solvm
asm=$lang/solvm-sob.phx
tmp=${TMPDIR:-/tmp}/solvm-tests.$$
mkdir -p "$tmp" || exit 1
trap 'rm -rf "$tmp"' EXIT

fail=0
ok() { printf '  ok    %s\n' "$1"; }
no() { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }

# ---- 1. the bytes, against the golden beside each program ----------------

for f in $lang/programs/*.sasm; do
    n=$(basename "$f" .sasm)
    gold=$lang/tests/golden/$n.sob
    if ! "$phx" --raw "$asm" "$f" > "$tmp/$n.sob" 2>"$tmp/$n.err"; then
        no "$n assembles"; sed 's/^/        /' "$tmp/$n.err" | head -3; continue
    fi
    if [ -n "${REGOLD:-}" ]; then cp "$tmp/$n.sob" "$gold"; fi
    if [ ! -f "$gold" ]; then
        no "$n has a golden"; continue
    fi
    if cmp -s "$tmp/$n.sob" "$gold"; then
        ok "$n.sasm assembles to the same bytes as before"
    else
        no "$n.sasm assembles to the same bytes as before"
    fi
done

# ---- 2. it writes back out as what it read -------------------------------

for f in $lang/programs/*.sasm; do
    n=$(basename "$f" .sasm)
    if ! "$phx" --driver render "$lang/solvm.phx" "$f" > "$tmp/$n.rt" 2>&1; then
        no "$n renders"; continue
    fi
    "$phx" --tree "$lang/solvm.phx" "$f"       > "$tmp/$n.t1" 2>&1
    "$phx" --tree "$lang/solvm.phx" "$tmp/$n.rt" > "$tmp/$n.t2" 2>&1
    if cmp -s "$tmp/$n.t1" "$tmp/$n.t2"; then
        ok "$n.sasm renders and re-parses to the same tree"
    else
        no "$n.sasm renders and re-parses to the same tree"
    fi
done

# ---- 3. and refuses what it must, for the reason it must -----------------
#
# The message matters as much as the refusal: every one of these is a mistake
# somebody will make, and the whole value is in being told which.

refuse() {
    what=$1; want=$2
    if out=$("$phx" --quiet --driver check "$asm" "$lang/tests/$what" 2>&1); then
        no "$what is refused"; return
    fi
    if printf '%s' "$out" | grep -qF -- "$want"; then
        ok "$what: $want"
    else
        no "$what is refused for the right reason"
        printf '%s\n' "$out" | sed 's/^/        /' | head -2
    fi
}

refuse no-such-label.sasm       "no label called 'nowhere'"
refuse backward-jump.sasm       "a backward jump is \`loop\`"
refuse forward-loop.sasm        "a forward jump is \`jump\`"
refuse no-halt.sasm             "the script has to end with halt"
refuse no-such-block.sasm       "no block called 'missing'"
refuse two-blocks-one-name.sasm "have the same name"
refuse slot-too-big.sasm        "a slot has to fit one byte"
refuse block-without-return.sasm "has to end with return"
refuse too-few-slots.sasm       "the receiver is slot 0"
refuse two-labels-one-name.sasm "two labels in the script have the same name"
refuse slot-past-frame.sasm     "slot 4 is past this frame, which has 2"

# ---- 4. and agrees with solas, which is the oracle -----------------------

sol=${SOLVEIG:-$root/../Solveig}
if [ ! -x "$sol/bin/solas" ] || [ ! -x "$sol/bin/solvm" ]; then
    printf '  --    the oracle needs a Solveig checkout, which is not here\n'
    [ "$fail" -eq 0 ]
    exit $?
fi

# The version is an equality in both directions, and `unsupported bytecode
# version` is the whole diagnosis, so it is worth a test of its own.
hdr=$sol/solum/include/solum/serialize.h
want=$(sed -n 's/^#define SOL_SOB_VERSION \([0-9]*\).*/\1/p' "$hdr")
have=$(sed -n 's/.*bytes(\([0-9]*\), 2), bytes(\$ownnslots.*/\1/p' "$asm")
if [ -n "$want" ] && [ "$want" = "$have" ]; then
    ok "the format version is SOL_SOB_VERSION, which is $want"
else
    no "the format version is SOL_SOB_VERSION ($hdr says $want, the assembler writes $have)"
fi

# One instruction per line, with the source-line column and the chunk's own
# name taken out: those are the two things two producers of one program are
# entitled to disagree about.
normalise() {
    "$sol/bin/solvm" --dump "$1" 2>/dev/null \
      | sed -E -e 's/^== .* ==$/== chunk ==/' \
               -e 's/^([0-9]{4})[[:space:]]+([0-9]+|\|)[[:space:]]/\1 /'
}

for s in $lang/oracle/*.sol; do
    n=$(basename "$s" .sol)
    mine=$lang/programs/$n.sasm
    [ -f "$mine" ] || { no "$n.sol has no assembly beside it"; continue; }

    if ! "$sol/bin/solas" "$s" -o "$tmp/$n-solas.sob" >"$tmp/$n.solas.err" 2>&1; then
        no "solas compiles $n.sol"; sed 's/^/        /' "$tmp/$n.solas.err" | head -3; continue
    fi

    a=$("$sol/bin/solvm" "$tmp/$n-solas.sob" 2>&1)
    b=$("$sol/bin/solvm" "$tmp/$n.sob" 2>&1)
    if [ "$a" = "$b" ]; then
        ok "$n prints what solas's does"
    else
        no "$n prints what solas's does"
        printf '        solas:     %s\n        assembler: %s\n' "$a" "$b"
    fi

    normalise "$tmp/$n-solas.sob" > "$tmp/$n.dis.a"
    normalise "$tmp/$n.sob"       > "$tmp/$n.dis.b"
    if cmp -s "$tmp/$n.dis.a" "$tmp/$n.dis.b"; then
        ok "$n compiles to the same instructions solas emits"
    else
        no "$n compiles to the same instructions solas emits"
        diff "$tmp/$n.dis.a" "$tmp/$n.dis.b" | sed 's/^/        /' | head -10
    fi
done

# ---- 5. and the tutorial does what it says ------------------------------

"$root/$lang/tests/tutorial.sh" || fail=$((fail + 1))

[ "$fail" -eq 0 ]
