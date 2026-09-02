program Structures(output);
type
  Small  = 1 .. 10;
  Row    = array [1 .. 10] of integer;
  Point  = record x, y : integer end;
var
  r : Row;
  p : Point;
  i : Small;
begin
  for i := 1 to 10 do r[i] := i * i;
  writeln(r[1]);
  writeln(r[10]);
  p.x := 3; p.y := 4;
  writeln(p.x + p.y);
  with p do writeln(x * y)
end.
