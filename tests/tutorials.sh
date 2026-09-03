#!/bin/sh
# tests/tutorials.sh -- run the two tutorials in docs/, and hold each page to
# what actually happens.
#
# Every step builds the file the page says to build, runs the command it says
# to run, and then checks that what came back **appears verbatim in the page**.
# A pasted output that drifts from the real one fails here rather than
# misleading somebody following along.
#
# That check exists because reading these pages did not find what running them
# did. `languages/solvm/tests/tutorial.sh` does the same for the assembler's
# own tutorial, and found four defects the same way.
#
# Needs `cc`, which the suite already assumes.

set -u

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
phx=$root/bin/phx

fail=0
tmp=${TMPDIR:-/tmp}/phx-tutorials.$$
mkdir -p "$tmp" || exit 1
trap 'rm -rf "$tmp"' EXIT

doc=""
says() {
    printf '%s' "$2" > "$tmp/got"
    if python3 -c "import sys; sys.exit(0 if open(sys.argv[2]).read().strip() in open(sys.argv[1]).read() else 1)" "$doc" "$tmp/got"; then
        printf '  ok    %s\n' "$1"
    else
        printf '  FAIL  %s -- the page does not say this:\n' "$1"
        printf '%s\n' "$2" | sed 's/^/        /' | head -12
        fail=1
    fi
}

# ====================================================================
# docs/tutorial-picture.md
# ====================================================================

doc=$root/docs/tutorial-picture.md
mkdir -p "$tmp/pic" && cd "$tmp/pic" || exit 1

cat > face.pic <<'X'
# a face
circle 50, 50, 40;
circle 35, 40, 5;
circle 65, 40, 5;
line 35, 65, 65, 65;
X

# ---- 1. the lexical half, and the fragment that has to be declared
cat > picture.phx <<'X'
digit   = "0" .. "9" .
number  = digit { digit } .
space   = ( " " | "\t" | "\n" ) { " " | "\t" | "\n" } .
comment = "#" { ! "\n" } .
symbol  = "," | ";" .

%skip space comment .
X
says "picture 1  the forgotten %fragment" \
     "$("$phx" picture.phx 2>&1 | head -4)"

printf '%%fragment digit .\n\n' | cat - picture.phx > t && mv t picture.phx
if "$phx" picture.phx >/dev/null 2>"$tmp/e" && [ ! -s "$tmp/e" ]; then
    printf '  ok    picture 1b and then no complaint, as the page says\n'
else
    printf '  FAIL  picture 1b the page says there is no complaint\n'; fail=1
fi

# ---- 2. the syntactic half, and a literal nothing spells
cat >> picture.phx <<'X'

%syntax .
%start picture .

picture = { shape } .

shape = "circle" number "," number "," number ";"
      | "line" number "," number "," number "," number ";" .
X
says "picture 2  a literal nothing spells" \
     "$("$phx" picture.phx face.pic 2>&1 | head -3)"

python3 - <<'PY'
s = open('picture.phx').read()
s = s.replace('''%fragment digit .

digit   = "0" .. "9" .
number  = digit { digit } .''', '''%fragment letter digit .

letter  = "a" .. "z" .
digit   = "0" .. "9" .

word    = letter { letter } .
number  = digit { digit } .''')
open('picture.phx', 'w').write(s)
PY
says "picture 2b the tokens"        "$("$phx" --tokens picture.phx face.pic | head -8)"
says "picture 2c the concrete tree" "$("$phx" picture.phx face.pic | head -10)"

# ---- 3. what a production builds
python3 - <<'PY'
s = open('picture.phx').read()
s = s.replace('''picture = { shape } .

shape = "circle" number "," number "," number ";"
      | "line" number "," number "," number "," number ";" .''',
'''picture = { shape } -> Picture(shapes: $1) .

shape = "circle" x:number "," y:number "," r:number ";"
          -> Circle(x: $x, y: $y, r: $r)
      | "line" x1:number "," y1:number "," x2:number "," y2:number ";"
          -> Line(x1: $x1, y1: $y1, x2: $x2, y2: $y2) .''')
open('picture.phx', 'w').write(s)
PY
says "picture 3  the tree"       "$("$phx" --tree picture.phx face.pic)"
says "picture 3b the vocabulary" "$("$phx" --nodes picture.phx)"

# ---- 4. a pass and a driver
cat >> picture.phx <<'X'

%pass emit-svg

  Circle : out = "  <circle cx=\"{}\" cy=\"{}\" r=\"{}\" fill=\"none\" stroke=\"black\" />"
             of $x, $y, $r .

  Line   : out = "  <line x1=\"{}\" y1=\"{}\" x2=\"{}\" y2=\"{}\" stroke=\"black\" />"
             of $x1, $y1, $x2, $y2 .

  Picture : out = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 100 100\">\n{}\n</svg>"
              of join($shapes.out, "\n") .

%driver svg = emit-svg -> out .
X
says "picture 4  the svg" "$("$phx" picture.phx face.pic)"

# ---- 5. a check
python3 - <<'PY'
s = open('picture.phx').read()
s = s.replace("\n%pass emit-svg", '''
%pass sane
  Circle ! int($r) = 0 : "a circle of radius {} draws nothing" of $r .

%pass emit-svg''')
s = s.replace("%driver svg = emit-svg -> out .",
              "%driver svg   = sane, emit-svg -> out .\n%driver check = sane .")
open('picture.phx', 'w').write(s)
PY
printf 'circle 10, 10, 0;\n' > flat.pic
says "picture 5  the check fires" "$("$phx" picture.phx flat.pic 2>&1)"
if "$phx" --driver check picture.phx face.pic >/dev/null 2>&1; then
    printf '  ok    picture 5b a validation driver says nothing and exits 0\n'
else
    printf '  FAIL  picture 5b a validation driver should exit 0\n'; fail=1
fi

# ---- 6. writing the compiler out
if "$phx" picture.phx -o picc.c >/dev/null 2>&1 && cc picc.c -o picc 2>/dev/null; then
    says "picture 6  the standalone compiler" "$(./picc face.pic | head -6)"
    says "picture 6b and it still refuses"    "$(./picc flat.pic 2>&1)"
else
    printf '  FAIL  picture 6 the compiler did not build\n'; fail=1
fi

# ---- 7. the language against the target
python3 - <<'PY'
s = open('picture.phx').read()
head, rest = s.split("\n%pass emit-svg")
open('picture.phx', 'w').write(head + "\n")
open('picture-svg.phx', 'w').write('%import "picture.phx" .\n\n%pass emit-svg' + rest)
PY
cat > picture-text.phx <<'X'
%import "picture.phx" .

%pass emit-text
  Circle  : out = "a circle of radius {} at ({}, {})" of $r, $x, $y .
  Line    : out = "a line from ({}, {}) to ({}, {})" of $x1, $y1, $x2, $y2 .
  Picture : out = join($shapes.out, "\n") .

%driver text = sane, emit-text -> out .
X
says "picture 7  a second target"    "$("$phx" picture-text.phx face.pic)"
says "picture 7b what it came from"  "$("$phx" --imports picture-text.phx)"
if "$phx" picture-svg.phx face.pic >/dev/null 2>&1; then
    printf '  ok    picture 7c and the first one still works\n'
else
    printf '  FAIL  picture 7c the split broke the svg target\n'; fail=1
fi

# ====================================================================
# docs/tutorial-assembler.md
# ====================================================================

doc=$root/docs/tutorial-assembler.md
mkdir -p "$tmp/asm" && cd "$tmp/asm" || exit 1

cat > sum.asm <<'X'
# add two numbers and print the answer, unless it is zero
    push 3
    push 4
    add
    jz  done
    print
done:
    halt
X
cat > asm.phx <<'X'
%fragment letter digit .

letter  = "a" .. "z" .
digit   = "0" .. "9" .

word    = letter { letter | digit } .
number  = digit { digit } .
space   = ( " " | "\t" | "\n" ) { " " | "\t" | "\n" } .
comment = "#" { ! "\n" } .
symbol  = ":" .

%skip space comment .

%syntax .
%start program .

program = { item } -> Program(items: $1) .

item = n:word ":"       -> Label(name: $n)
     | "push" v:number  -> Push(value: $v)
     | "jz"   t:word    -> Jz(target: $t)
     | "jmp"  t:word    -> Jmp(target: $t)
     | "add"            -> Add
     | "print"          -> Print
     | "halt"           -> Halt .
X
says "assembler 1  the tree" "$("$phx" --tree asm.phx sum.asm)"

# ---- 2. the attempt that cannot work
cp asm.phx grammar.phx
cat >> asm.phx <<'X'

%pass assemble
  thread pc = 0

  Push : pc = $pc + 2 .
  Jz   : pc = $pc + 2 .
  Jmp  : pc = $pc + 2 .
  otherwise pc = $pc + 1

  Label : entry = [[$name, $pc]] .
  otherwise entry = []

  Program : labels = flatten($items.entry)
          : down table = $labels
          : out = join($items.out, "\n") .
X
says "assembler 2  one pass is refused" "$("$phx" asm.phx sum.asm 2>&1 | head -4)"

# ---- 3 and 4. two passes
cp grammar.phx asm.phx
cat >> asm.phx <<'X'

%pass layout
  thread pc = 0

  Push : pc = $pc + 2 .
  Jz   : pc = $pc + 2 .
  Jmp  : pc = $pc + 2 .
  otherwise pc = $pc + 1

  Label : entry = [[$name, $pc]] .
  otherwise entry = []

  Program : labels = flatten($items.entry) .

%pass listing
  Program : down table = $labels
          : out = join($items.out, "\n") .

  Label : out = "{}:" of $name .
  Push  : out = "    push {}" of $value .
  Add   : out = "    add" .
  Print : out = "    print" .
  Halt  : out = "    halt" .

  Jz : out = "    jz {}" of lookup($table, $target)
     ! not defined($table, $target) : "no label called '{}'" of $target .
  Jmp : out = "    jmp {}" of lookup($table, $target)
      ! not defined($table, $target) : "no label called '{}'" of $target .

%driver listing = layout, listing -> out .
X
says "assembler 3  the label table" \
     "$("$phx" --run layout --show labels asm.phx sum.asm 2>&1)"
says "assembler 4  the listing" "$("$phx" asm.phx sum.asm)"

printf '    jz nowhere\n    halt\n' > bad.asm
says "assembler 4b an unknown label" "$("$phx" asm.phx bad.asm 2>&1)"

sed 's/^%driver listing = layout, listing -> out ./%driver listing = listing -> out ./' \
    asm.phx > nolayout.phx
says "assembler 4c a driver in the wrong order" \
     "$(sed 's/^nolayout\.phx/asm.phx/' <<EOF
$("$phx" nolayout.phx sum.asm 2>&1 | head -3)
EOF
)"

# ---- 5. the same tree as bytes
cat >> asm.phx <<'X'

%pass emit-code
  Program : down table = $labels
          : out = join($items.out) .

  Label : out = "" .
  Push  : out = join([bytes(1, 1), bytes(int($value), 1)]) .
  Add   : out = bytes(2, 1) .
  Print : out = bytes(3, 1) .
  Halt  : out = bytes(4, 1) .

  Jz  : out = join([bytes(5, 1), bytes(lookup($table, $target), 1)])
      ! not defined($table, $target) : "no label called '{}'" of $target .
  Jmp : out = join([bytes(6, 1), bytes(lookup($table, $target), 1)])
      ! not defined($table, $target) : "no label called '{}'" of $target .

%driver code = layout, emit-code -> out .

%pass linetable
  Program : lines = join(bytes($items.pos.line, 2)) .

%driver lt = linetable -> lines .
X
"$phx" --driver code --raw asm.phx sum.asm > sum.bin
if command -v xxd >/dev/null 2>&1; then
    says "assembler 5  the bytes"      "$(xxd sum.bin)"
    says "assembler 5b the line table" "$("$phx" --driver lt --raw asm.phx sum.asm | xxd)"
else
    printf '  --    assembler 5 needs xxd, which is not here\n'
fi

# ---- 6. and a compiler it wrote agrees
if "$phx" asm.phx -o asmc.c >/dev/null 2>&1 && cc asmc.c -o asmc 2>/dev/null; then
    ./asmc --driver code --raw sum.asm > sum2.bin
    if cmp -s sum.bin sum2.bin; then
        printf '  ok    assembler 6  byte for byte identical, as the page claims\n'
    else
        printf '  FAIL  assembler 6  the page claims these are identical\n'; fail=1
    fi
else
    printf '  FAIL  assembler 6 the compiler did not build\n'; fail=1
fi

[ "$fail" -eq 0 ]
