program Matrix(output);
type
  Grid = array [1 .. 3] of array [1 .. 3] of integer;
var
  g : Grid;
  i, j, n : integer;
begin
  n := 0;
  for i := 1 to 3 do
    for j := 1 to 3 do
      begin
        n := n + 1;
        g[i][j] := n
      end;
  writeln(g[1][1]);
  writeln(g[2][2]);
  writeln(g[3][3])
end.
