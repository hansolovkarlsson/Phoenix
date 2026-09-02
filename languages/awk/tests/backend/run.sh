#!/bin/sh
# languages/awk/tests/backend/run.sh -- awk compiled to C, against awk.
#
# **The conformance rule, with a third language under it.** Each program is
# compiled by `awk-c.phx` into C, that C is compiled by `cc`, and what it
# prints has to be what `/usr/bin/awk` prints on the same input -- byte for
# byte, with nothing normalised.
#
# These are stage one: values, fields, the main loop, `print` and `printf`,
# arithmetic, comparison, concatenation and control flow. Arrays, functions and
# regular expressions are refused by name, and `../refused-by-the-backend/`
# holds one of each so that the refusals are checked rather than assumed.
set -u
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$here/../../../.." && pwd)
phx="$root/bin/phx"
desc="$root/languages/awk/awk-c.phx"

command -v awk >/dev/null 2>&1 || { echo "  --    needs awk, which is not here"; exit 0; }

out="$root/build/awk-backend"; rm -rf "$out"; mkdir -p "$out/run"
trap 'rm -rf "$out"' EXIT

same=0; differ=0
for f in "$here"/*.awk; do
    n=$(basename "$f" .awk)
    in=/dev/null; [ -f "$here/$n.in" ] && in="$here/$n.in"

    if ! "$phx" --driver c "$desc" "$f" > "$out/$n.c" 2>"$out/err"; then
        differ=$((differ+1)); echo "  will not compile: $n.awk"
        sed 's/^/      /' "$out/err" | head -3; continue
    fi
    if ! cc -o "$out/$n" "$out/$n.c" 2>"$out/cc-err"; then
        differ=$((differ+1)); echo "  the C will not build: $n.awk"
        sed 's/^/      /' "$out/cc-err" | head -3; continue
    fi

    # The compiled program is given the file the way awk is given it, rather
    # than fed on stdin -- which is the same test and also tests that a
    # compiled program takes its input where awk takes it.
    ( cd "$out/run" && awk -f "$f" "$in" ) > "$out/want" 2>&1
    ( cd "$out/run" && "$out/$n" "$in" )   > "$out/mine" 2>&1

    if cmp -s "$out/want" "$out/mine"; then same=$((same+1))
    else
        differ=$((differ+1)); echo "  $n.awk: compiled and interpreted disagree"
        diff "$out/want" "$out/mine" | head -8 | sed 's/^/      /'
    fi
done
# **And the corpus**, which is the point of the whole exercise: awk that
# e2fsprogs, ncurses and vim ship, compiled to C and run against awk on the
# same input. `corpus-in/` holds what each one wants; the three table
# generators are run the way their makefiles run them, with `-v outfile=`.
corpus=0
for n in mve generate mk-test ct_c et_c et_h; do
    f="$here/../corpus/$n.awk"
    opts=""
    case "$n" in
      mve)            in="$here/corpus-in/mve.in" ;;
      ct_c|et_c|et_h) in="$here/corpus-in/table.in"; opts="-v outfile=/dev/stdout" ;;
      *)              in="$here/corpus-in/plain.in" ;;
    esac

    if ! "$phx" --driver c "$desc" "$f" > "$out/$n.c" 2>"$out/err" \
       || ! cc -o "$out/$n" "$out/$n.c" 2>"$out/cc-err"; then
        differ=$((differ+1)); echo "  will not compile: $n.awk"
        sed 's/^/      /' "$out/err" "$out/cc-err" 2>/dev/null | head -3; continue
    fi

    # shellcheck disable=SC2086
    ( cd "$out/run" && awk $opts -f "$f" "$in" ) > "$out/want" 2>&1
    # shellcheck disable=SC2086
    ( cd "$out/run" && "$out/$n" $opts "$in" )  > "$out/mine" 2>&1

    if cmp -s "$out/want" "$out/mine"; then corpus=$((corpus+1))
    else
        differ=$((differ+1)); echo "  $n.awk: compiled and interpreted disagree"
        diff "$out/want" "$out/mine" | head -8 | sed 's/^/      /'
    fi
done

printf '%d awk programs and %d other people wrote compile to C that prints' \
       "$same" "$corpus"
printf ' what awk prints, %d do not\n' "$differ"
[ "$differ" -eq 0 ]
