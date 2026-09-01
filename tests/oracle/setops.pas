program SetOps(output);
type
  Digit  = 0 .. 9;
  Digits = set of Digit;
var
  s, t, u : Digits;
  i : integer;

procedure Show(v : Digits);
var k : integer;
begin
  for k := 0 to 9 do
    if k in v then write(k:2);
  writeln
end;

begin
  s := [1, 2, 3];
  t := [3, 4, 5];
  Show(s + t);
  Show(s * t);
  Show(s - t);
  u := [2 .. 6];
  Show(u);
  Show([]);
  i := 4;
  if i in u then writeln('in') else writeln('out')
end.
