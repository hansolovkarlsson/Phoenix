#!/bin/sh
# languages/c/tests/oracle/run.sh -- the same C, compiled two ways, giving one
# answer.
#
# Every program here is compiled by `cc` and by Phoenix -- whose output is
# arm64 assembly that `cc` then assembles and links -- both are run, and what
# they wrote and what they exited with are compared. **cc is the oracle**:
# where they differ, Phoenix is wrong until somebody shows otherwise. Nothing
# in this directory has a hand-written expected result, which is the rule
# ROADMAP 6 set for the whole arc.
#
# The exit status is compared because for the first constructs it is the only
# thing a program can say: `return 42;` reaches the shell as 42, and there is
# no `printf` until a function can be called. The shell keeps the low eight
# bits, so both sides are read the same way and a return of 1000000 is 64 on
# both.
#
#   languages/c/tests/oracle/run.sh              all of them
#   languages/c/tests/oracle/run.sh return-42    one of them
#
# `cc` is both the oracle and the assembler, so a machine without it has
# nothing to skip *to*: this script does not run there, and neither does
# `make`.

set -u
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$here/../../../.." && pwd)
phx="$root/bin/phx"
desc="$root/languages/c/c-arm64.phx"

if [ "$(uname -m)" != "arm64" ]; then
    echo "this machine is not arm64 -- the oracle is skipped, not failed"
    exit 0
fi

tmp="$root/build/c-oracle"; rm -rf "$tmp"; mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

# Every program is run under a limit, both compiles of it and both runs, so
# that one which never finishes, by looping or by printing without end, is a
# failure with its name on it and not a suite that hangs. `limit` exits 124
# and says `did not finish` when it stops one; 124 alone is not enough,
# because a program here may *return* 124 and the exit status is the thing
# being compared. See tests/limit.c.
limit="$root/bin/limit"
secs=${PHX_LIMIT:-20}
if [ ! -x "$limit" ]; then
    echo "no $limit: run make first"
    exit 1
fi

# ran_out <status> <stderr file> -- whether that run was stopped.
ran_out() {
    [ "$1" = 124 ] && grep -q 'did not finish' "$2"
}

# why <stderr file> -- how it did not finish, in limit's words.
why() {
    grep -o 'did not finish.*' "$1" | tail -1
}

pass=0
fail=0
only=${1:-}

for src in "$here"/*.c; do
    name=$(basename "$src" .c)
    [ -n "$only" ] && [ "$only" != "$name" ] && continue

    # The oracle. `-w`, because a program written to probe the subset may be
    # one cc has an opinion about, and the opinion is not the answer. One
    # opinion survives `-w`: this cc makes a chained comparison an error, and
    # `3 > 2 > 1` is C11 6.5.8 as written, so that one is downgraded by name.
    if ! cc -w -Wno-error=parentheses -o "$tmp/$name.want" "$src" \
            >"$tmp/$name.cc.log" 2>&1; then
        printf '  SKIP  %-14s cc would not compile it\n' "$name"
        sed 's/^/          /' "$tmp/$name.cc.log" | grep -i 'error' | head -2
        continue
    fi
    want=$("$limit" "$secs" "$tmp/$name.want" 2>"$tmp/$name.want.err"); want_status=$?
    if ran_out "$want_status" "$tmp/$name.want.err"; then
        printf '  FAIL  %-14s the program cc made %s\n' "$name" "$(why "$tmp/$name.want.err")"
        fail=$((fail + 1))
        continue
    fi

    # Phoenix.
    if ! "$limit" "$secs" "$phx" --driver arm64 "$desc" "$src" \
            >"$tmp/$name.s" 2>"$tmp/$name.phx.log"; then
        printf '  FAIL  %-14s phoenix would not compile it\n' "$name"
        sed 's/^/          /' "$tmp/$name.phx.log" | head -3
        fail=$((fail + 1))
        continue
    fi
    if ! cc -o "$tmp/$name.got" "$tmp/$name.s" 2>"$tmp/$name.as.log"; then
        printf '  FAIL  %-14s the assembly it emitted would not assemble\n' "$name"
        sed 's/^/          /' "$tmp/$name.as.log" | head -3
        fail=$((fail + 1))
        continue
    fi
    got=$("$limit" "$secs" "$tmp/$name.got" 2>"$tmp/$name.got.err"); got_status=$?
    if ran_out "$got_status" "$tmp/$name.got.err"; then
        printf '  FAIL  %-14s the program phoenix made %s\n' "$name" "$(why "$tmp/$name.got.err")"
        fail=$((fail + 1))
        continue
    fi

    if [ "$want" = "$got" ] && [ "$want_status" = "$got_status" ]; then
        pass=$((pass + 1))
        printf '  ok    %s\n' "$name"
    else
        fail=$((fail + 1))
        printf '  FAIL  %s\n' "$name"
        if [ "$want_status" != "$got_status" ]; then
            printf '          cc exits %s, phoenix exits %s\n' "$want_status" "$got_status"
        fi
        if [ "$want" != "$got" ]; then
            printf '%s\n' "$want" > "$tmp/want"
            printf '%s\n' "$got"  > "$tmp/got"
            diff "$tmp/want" "$tmp/got" | head -6 | sed 's/^/          /'
        fi
    fi
done

printf '\n%d agree with cc, %d do not\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
