program Bounds(output);
type
  Low  = array [5 .. 9] of integer;
  Neg  = array [-3 .. 3] of integer;
var
  a : Low;
  b : Neg;
  i : integer;
begin
  for i := 5 to 9 do a[i] := i * 10;
  writeln(a[5]);
  writeln(a[9]);
  for i := -3 to 3 do b[i] := i;
  writeln(b[-3]);
  writeln(b[0]);
  writeln(b[3])
end.
