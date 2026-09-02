#!/bin/sh
# bench/run.sh -- is the matcher linear in its input?
#
# The question this answers is not how fast Phoenix is. It is whether the work
# grows in proportion to the input, because a PEG with no memoisation need not,
# and a bad complexity is a defect where a constant factor is a decision.
#
# Steps are deterministic, so the shape of the curve is exact and not a
# measurement. The wall clock at the end is only for scale.

set -u
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
phx="$root/bin/phx"
tmp="$root/build/bench"; rm -rf "$tmp"; mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

grammar=${1:-"$root/languages/pascal/pascal.phx"}

for shape in width expr nest blocks; do
    printf '\n%s\n' "$shape"
    printf '%8s %10s %8s %14s %12s %10s\n' \
           n bytes tokens match-steps per-token ms

    prev_ratio=0
    for n in 100 200 400 800 1600; do
        awk -v n="$n" -v shape="$shape" -f "$root/bench/generate.awk" > "$tmp/b.pas"

        stats=$("$phx" --stats --quiet --tree "$grammar" "$tmp/b.pas" 2>&1 >/dev/null)
        bytes=$(printf '%s' "$stats" | awk '{print $1}')
        toks=$(printf '%s' "$stats" | awk '{print $3}')
        steps=$(printf '%s' "$stats" | awk '{print $9}')

        # Ten runs, so that a few milliseconds is measurable.
        start=$(perl -MTime::HiRes=time -e 'print time')
        i=0
        while [ $i -lt 10 ]; do
            "$phx" --quiet --tree "$grammar" "$tmp/b.pas" >/dev/null 2>&1
            i=$((i + 1))
        done
        end=$(perl -MTime::HiRes=time -e 'print time')
        ms=$(perl -e 'printf "%.1f", ('"$end"' - '"$start"') * 100')

        ratio=$(perl -e 'printf "%.1f", '"$steps"' / '"$toks")
        printf '%8s %10s %8s %14s %12s %10s\n' "$n" "$bytes" "$toks" "$steps" "$ratio" "$ms"
    done
done

printf '\nA flat per-token column is linear. A rising one is not.\n'
