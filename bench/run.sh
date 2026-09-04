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
gen=${2:-"$root/bench/generate.awk"}
shapes=${3:-"width expr nest blocks"}
sizes=${4:-"100 200 400 800 1600"}

for shape in $shapes; do
    printf '\n%s\n' "$shape"
    printf '%8s %10s %8s %14s %12s %10s %8s\n' \
           n bytes tokens match-steps per-token ms depth

    prev_ratio=0
    for n in $sizes; do
        awk -v n="$n" -v shape="$shape" -f "$gen" > "$tmp/b.pas"

        # **Check that it succeeded.** This did not, once, and the failure was
        # silent: on error `--stats` prints nothing and the diagnosis arrives
        # on the same stream, so `awk '{print $9}'` picked a word out of the
        # error message and the row looked like a measurement. One number in
        # `docs/performance.md` came from exactly that, for a shape that
        # cannot complete.
        if ! stats=$("$phx" --stats --quiet --tree "$grammar" "$tmp/b.pas" 2>&1 >/dev/null); then
            why=$(printf '%s' "$stats" | sed -n '1s/.*error: //p' | cut -c1-46)
            printf '%8s %10s %8s %14s %12s %10s\n' \
                   "$n" "-" "-" "-" "-" "${why:-failed}"
            continue
        fi
        bytes=$(printf '%s' "$stats" | awk '{print $1}')
        toks=$(printf '%s' "$stats" | awk '{print $3}')
        steps=$(printf '%s' "$stats" | awk '{print $9}')
        depth=$(printf '%s' "$stats" | awk '{print $12}')

        # And that the fields are numbers, so a change to the --stats format
        # is a loud failure rather than a quiet one.
        case "$toks$steps" in
            *[!0-9]* | "") printf '%8s  --stats format changed\n' "$n"; continue ;;
        esac

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
        printf '%8s %10s %8s %14s %12s %10s %8s\n' \
               "$n" "$bytes" "$toks" "$steps" "$ratio" "$ms" "$depth"
    done
done

printf '\nA flat per-token column is linear. A rising one is not.\n'
printf 'A row with a reason instead of numbers did not complete; that is a\n'
printf 'result too, and the reason says which ceiling it met.\n'
