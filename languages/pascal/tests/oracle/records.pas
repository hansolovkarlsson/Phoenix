program Records(output);
type Pt = record x, y : integer end;
var a, b : Pt;
begin
  a.x := 1; a.y := 2;
  b := a;
  b.x := 9;
  writeln(a.x);
  writeln(b.x);
  writeln(a.y + b.y)
end.
