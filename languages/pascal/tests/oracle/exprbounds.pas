program ExprBounds(output);
var i, n, s : integer;
begin
  n := 2;
  s := 0;
  for i := n - 1 to n * 2 do s := s + i;
  writeln(s);
  for i := n * 3 downto n do s := s - 1;
  writeln(s)
end.
