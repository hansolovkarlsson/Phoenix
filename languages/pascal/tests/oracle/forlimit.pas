program ForLimit(output);
var i, n, c : integer;
begin
  n := 3;
  c := 0;
  for i := 1 to n do
    begin
      n := 1;
      c := c + 1
    end;
  writeln(c);
  writeln(n)
end.
