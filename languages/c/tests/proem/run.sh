#!/bin/sh
# languages/c/tests/proem/run.sh -- what a real program stops at.
#
# Proem is a C preprocessor written elsewhere, cpp again since 2026-10-06,
# and the first program not written for this subset that Phoenix was run
# on. Each of its source files is preprocessed by `cc -E` and put through
# the `check` driver, and the first stop in each is printed, or
# `accepted`. The ROADMAP 6 entries since 2026-10-02 were chosen from what
# this printed, and not from a count of words in the source, which had
# chosen them until then and missed the commonest stop.
#
# **Apple's headers stop every file first**, `long double` in <stddef.h> and
# a `union` in Darwin's `__mbstate_t`, so the files are preprocessed against
# `stubs/` instead: what Proem uses of each header, declared in the subset,
# with `va_list` left to cc's builtins, which the subset reads since
# 2026-10-04, so that a variadic function defined showed as a stop. Each file must pass `cc -std=c11 -pedantic -Wall` against
# the stubs before it is checked, so a stop printed here is Phoenix's and
# not a stub's; a file that fails is reported as the stubs falling short.
#
# Proem is not in this repository, so this is not part of `make test`: it
# reads a checkout, by default its place in DevTools beside this
# repository, `DevTools/cpp`, where it has lived since 2026-10-06.
#
#   languages/c/tests/proem/run.sh                  ../DevTools/cpp
#   languages/c/tests/proem/run.sh ~/src/Proem      another checkout
#
# A probe finds only the first stop in each file, and the first in the
# earliest phase that refuses, not the first by line: the lexer reads the
# whole file before any pass runs.

set -u
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$here/../../../.." && pwd)
phx="$root/bin/phx"
desc="$root/languages/c/c-arm64.phx"
proem=${1:-"$root/../DevTools/cpp"}

if [ ! -d "$proem/lib" ]; then
    echo "no Proem checkout at $proem -- give its path"
    exit 2
fi
proem=$(CDPATH= cd -- "$proem" && pwd)

tmp="$root/build/c-proem"; rm -rf "$tmp"; mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

accepted=0
stopped=0
short=0
for src in "$proem"/lib/*.c "$proem"/driver/*.c; do
    [ -f "$src" ] || continue
    name=${src#"$proem"/}
    flags="-std=c11 -nostdinc -I$here/stubs -I$proem/lib -I$proem/include"
    if ! why=$(cc $flags -pedantic -Wall -fsyntax-only "$src" 2>&1) || [ -n "$why" ]; then
        printf '  %-18s the stubs fall short: %s\n' "$name" \
            "$(printf '%s' "$why" | grep -m1 -E 'error|warning' | sed -E 's/.*(error|warning): //')"
        short=$((short + 1))
        continue
    fi
    cc $flags -E -P "$src" > "$tmp/out.i"
    if stop=$("$phx" --driver check "$desc" "$tmp/out.i" 2>&1); then
        printf '  %-18s accepted\n' "$name"
        accepted=$((accepted + 1))
    else
        printf '  %-18s %s\n' "$name" "$(printf '%s' "$stop" | head -1 | sed "s#^$tmp/out.i:##")"
        stopped=$((stopped + 1))
    fi
done

echo
echo "$accepted accepted, $stopped stopped, $short the stubs could not compile"
[ "$short" -eq 0 ]
