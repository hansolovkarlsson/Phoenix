#!/usr/bin/env python3
"""Check the .phx grammar against the notation's own description of itself.

languages/phx/phoenix.phx describes the tokens of a .phx file, so

    bin/phx languages/phx/phoenix.phx some.phx --tokens

lexes any description the way the notation says it is lexed. That is the
oracle here, and it is run over every .phx file in the repository:

  - every token phx reports is outside a comment in the grammar's reading,
  - every literal phx reports is a string, all of it, and nothing more,
  - every directive phx reports is a directive,
  - and every character the grammar reads as code is inside a token phx
    reported, so a comment the grammar failed to see is found too.

What the token stream cannot judge is which name is a production, which an
attribute and which a label, and the cases at the end hold those.

The engine below is a TextMate matcher small enough to read: match, begin and
end, include and captures, one line at a time as VS Code runs it. It is not
vscode-textmate, so a difference between the two is possible, but Oniguruma
and Python's re agree on everything this grammar writes. There is no node
here and none is needed.

    python3 editors/vscode/test.py        (after make, which builds bin/phx)
"""
import json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
PHX = os.path.join(ROOT, 'bin', 'phx')
SELF = os.path.join(ROOT, 'languages', 'phx', 'phoenix.phx')
GRAMMAR = json.load(open(os.path.join(HERE, 'syntaxes', 'phx.tmLanguage.json')))

def rules(patterns):
    """Flatten includes into a list of rule dicts."""
    out = []
    for p in patterns:
        if 'include' not in p:
            out.append(p)
            continue
        r = GRAMMAR['repository'][p['include'][1:]]
        out.extend(rules(r['patterns']) if 'patterns' in r and 'begin' not in r else [r])
    return out

_cache = {}
def rx(src):
    if src not in _cache:
        _cache[src] = re.compile(src)
    return _cache[src]

def captured(m, captures, scopes):
    toks, pos = [], m.start()
    for k in sorted(captures, key=int):
        i = int(k)
        if m.start(i) < pos or m.start(i) == m.end(i):
            continue
        if m.start(i) > pos:
            toks.append((pos, m.start(i), scopes))
        toks.append((m.start(i), m.end(i), scopes + [captures[k]['name']]))
        pos = m.end(i)
    if pos < m.end():
        toks.append((pos, m.end(), scopes))
    return toks

def tokenise(lines):
    """Yield (line number, tokens) with each token (start, end, scopes)."""
    stack = []                       # the begin/end rules open, innermost last
    top = rules(GRAMMAR['patterns'])
    for n, line in enumerate(lines, 1):
        toks, pos = [], 0
        while pos <= len(line):
            scopes = [r['name'] for r in stack if 'name' in r]
            cands = rules(stack[-1].get('patterns', [])) if stack else top
            best, which = None, None
            if stack:
                best = rx(stack[-1]['end']).search(line, pos)
                which = 'end'
            for r in cands:
                m = rx(r['match'] if 'match' in r else r['begin']).search(line, pos)
                if m and (best is None or m.start() < best.start()):
                    best, which = m, r
            if best is None:
                if pos < len(line):
                    toks.append((pos, len(line), scopes))
                break
            if best.start() > pos:
                toks.append((pos, best.start(), scopes))
            if which == 'end':
                toks.extend(captured(best, stack[-1].get('endCaptures', {}), scopes))
                stack.pop()
            elif 'match' in which:
                inner = scopes + ([which['name']] if 'name' in which else [])
                toks.extend(captured(best, which.get('captures', {}), inner))
            else:
                stack.append(which)
                inner = scopes + ([which['name']] if 'name' in which else [])
                toks.extend(captured(best, which.get('beginCaptures', {}), inner))
            pos = best.end() if best.end() > best.start() else best.end() + 1
        yield n, toks
    yield None, stack

def scopes_by_char(lines):
    """For each line, a list of scope lists, one per character."""
    out, left = [], None
    for n, toks in tokenise(lines):
        if n is None:
            left = toks
            break
        row = [[] for _ in lines[n - 1]]
        for s, e, sc in toks:
            for i in range(s, min(e, len(row))):
                row[i] = sc
        out.append(row)
    return out, left

def phx_tokens(path):
    out = subprocess.run([PHX, SELF, path, '--tokens'], capture_output=True, check=True).stdout
    for line in out.decode('utf-8').splitlines():
        m = re.match(r'\s*(\d+):(\d+)\s+(\S+)\s+(.*)$', line)
        if m:
            yield int(m[1]), int(m[2]), m[3], m[4]

failures = 0
def fail(where, why):
    global failures
    failures += 1
    if failures <= 40:
        print(f'  FAIL  {where}: {why}')

def check_file(path):
    raw = open(path, 'rb').read()
    lines = raw.decode('utf-8').split('\n')
    chars, left = scopes_by_char(lines)
    rel = os.path.relpath(path, ROOT)
    if left:
        fail(rel, f"ends inside {[r.get('name', r.get('begin')) for r in left]}")
    covered = [bytearray(len(l)) for l in lines]
    def col(ln, byte):                      # phx counts bytes, the engine characters
        return len(lines[ln - 1].encode('utf-8')[:byte - 1].decode('utf-8', 'replace'))
    for ln, bc, kind, text in phx_tokens(path):
        c = col(ln, bc)
        # A literal may run over lines; judge its first line, which is all
        # the token stream prints.
        width = len(text) if '\n' not in text else len(lines[ln - 1]) - c
        width = min(width, len(lines[ln - 1]) - c)
        span = chars[ln - 1][c:c + width]
        for i in range(c, c + width):
            covered[ln - 1][i] = 1
        where = f'{rel}:{ln}:{bc}'
        if any(any(s.startswith('comment') for s in sc) for sc in span):
            fail(where, f'{kind} {text!r} is coloured as a comment')
        if kind == 'literal' and not all(any(s.startswith('string') for s in sc) for sc in span):
            fail(where, f'literal {text!r} is not coloured as a string throughout')
        if kind == 'directive' and not all('keyword.control.directive.phx' in sc for sc in span):
            fail(where, f'directive {text!r} is not coloured as one')
        if kind != 'literal' and any(any(s.startswith('string') for s in sc) for sc in span):
            fail(where, f'{kind} {text!r} is coloured as a string')
    for ln, row in enumerate(chars, 1):
        line = lines[ln - 1]
        for i, sc in enumerate(row):
            if line[i].isspace() or covered[ln - 1][i]:
                continue
            if not any(s.startswith(('comment', 'string')) for s in sc):
                fail(f'{rel}:{ln}:{i + 1}', f'{line[i]!r} is coloured as code and is in no token')
                break

# The structural cases: a line, and what named pieces of it must be coloured.
CASES = [
    ('function = r:base t:{ "*" } n:name "(" p:params ")" ";"',
     [('function', 'entity.name.function.production.phx'),
      ('r', 'variable.parameter.phx'), ('base', None), ('"*"', 'string.quoted.double.phx')]),
    ('  Prototype : rptrs = $stars + $ret.ptrs',
     [('Prototype', 'entity.name.type.node.phx'), ('rptrs', 'entity.other.attribute-name.phx'),
      ('$stars', 'variable.other.reference.phx'), ('.ptrs', 'variable.other.property.phx')]),
    ('  Function : down gives = lookup([[0, $ret.tagname]], $rptrs, "") .',
     [('down', 'storage.modifier.down.phx'), ('gives', 'entity.other.attribute-name.phx'),
      ('lookup', 'support.function.phx'), ('""', 'string.quoted.double.phx'),
      ('.', 'punctuation.terminator.phx')]),
    ('  Case : v = bitor(bitand($a, 12), bitxor(3, 5)) .',
     [('bitor', 'support.function.phx'), ('bitand', 'support.function.phx'),
      ('bitxor', 'support.function.phx')]),
    ('  thread rets = empty',
     [('thread', 'storage.modifier.phx'), ('rets', 'entity.other.attribute-name.phx'),
      ('empty', 'constant.language.phx')]),
    ('  otherwise wide = $type = 0 and $width = 8',
     [('otherwise', 'storage.modifier.phx'), ('wide', 'entity.other.attribute-name.phx'),
      ('0', 'constant.numeric.phx'), ('and', 'keyword.operator.word.phx')]),
    ('            ! $ret.ptrs > 0 : "\'{}\' returns a pointer" of $name',
     [('!', 'keyword.operator.negation.phx'), ('{}', 'constant.other.placeholder.phx'),
      ('of', 'keyword.operator.word.phx')]),
    ('primary = n:name "(" a:args ")" -> Call(name: $n, args: $a)',
     [('->', 'keyword.operator.arrow.phx'), ('Call', 'entity.name.type.node.phx'),
      ('name:', 'variable.parameter.phx'), ('$n', 'variable.other.reference.phx')]),
    ('letter = "a" .. "z" | "A" .. "Z" | "_" .',
     [('..', 'keyword.operator.range.phx'), ('|', 'keyword.operator.alternation.phx')]),
    ('%driver arm64 = functions, locals, relax until labels, emit-arm64 -> out .',
     [('%driver', 'keyword.control.directive.phx'), ('arm64', 'entity.name.section.phx'),
      ('locals', 'entity.name.function.stage.phx'), ('until', 'keyword.other.until.phx'),
      ('out', 'variable.other.property.phx')]),
    ('%rewrite unparen bottomup',
     [('unparen', 'entity.name.section.phx'), ('bottomup', 'support.constant.strategy.phx')]),
    ('%pass types',
     [('%pass', 'keyword.control.directive.phx'), ('types', 'entity.name.section.phx')]),
    ('    declare Typedef.name',
     [('declare', 'keyword.other.names.phx'), ('.name', 'variable.other.property.phx')]),
    ('(* **A call** is `f(x)`, and `*)` ends it here, as phx ends it',
     [('**A call**', 'markup.bold.phx'), ('`f(x)`', 'markup.inline.raw.phx'),
      ('ends', None)]),
    ('(* **a comment *) ends inside bold**',
     [('ends', None)]),
    ('x = y ; a comment, which "is not a string" (* nor this',
     [('x', 'entity.name.function.production.phx'), ('; a comment', 'comment.line.semicolon.phx'),
      ('"is', 'comment.line.semicolon.phx')]),
    ('escape = "\\\\" ( "n" | "x" hex hex ) .',
     [('\\\\', 'constant.character.escape.phx')]),
]
PREFIX = {'    declare Typedef.name': '%names typedef-names\n'}

def check_cases():
    for line, wants in CASES:
        pre = PREFIX.get(line, '')
        lines = (pre + line).split('\n')
        chars, _ = scopes_by_char(lines)
        row, pos = chars[-1], 0
        for text, want in wants:
            i = line.find(text, pos)
            if i < 0:
                fail(line, f'{text!r} is not in the case')
                continue
            pos = i + len(text)
            got = row[i]
            if want is None:
                if got:
                    fail(line, f'{text!r} should be plain, and is {got}')
            elif want not in got:
                fail(line, f'{text!r} should be {want}, and is {got}')

if not os.path.exists(PHX):
    sys.exit('bin/phx is not built: run make first')
files = subprocess.run(['git', 'ls-files', '*.phx'], cwd=ROOT, capture_output=True,
                       text=True, check=True).stdout.split()
for f in files:
    check_file(os.path.join(ROOT, f))
check_cases()
print(f'{len(files)} files and {len(CASES)} cases: '
      + ('all agree' if failures == 0 else f'{failures} failures'))
sys.exit(failures > 0)
