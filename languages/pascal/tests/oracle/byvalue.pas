program ByValue(output);
type
  Row = array [1 .. 3] of integer;
  Pt  = record x, y : integer end;
var
  r : Row;
  p : Pt;
  i : integer;

procedure TouchArray(a : Row);
begin
  a[1] := 99
end;

procedure TouchRecord(q : Pt);
begin
  q.x := 99
end;

begin
  for i := 1 to 3 do r[i] := i;
  p.x := 1; p.y := 2;
  TouchArray(r);
  TouchRecord(p);
  writeln(r[1]);
  writeln(p.x)
end.
