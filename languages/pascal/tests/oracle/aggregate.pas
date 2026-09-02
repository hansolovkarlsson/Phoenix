program Aggregate(output);
type
  Point = record x, y : integer end;
  Path  = array [1 .. 3] of Point;
  Box   = record corners : Path; name : char end;
var
  b : Box;
  i : integer;
begin
  for i := 1 to 3 do
    begin
      b.corners[i].x := i;
      b.corners[i].y := i * i
    end;
  b.name := 'B';
  writeln(b.corners[2].x);
  writeln(b.corners[3].y);
  writeln(b.name);
  with b do writeln(corners[1].y)
end.
