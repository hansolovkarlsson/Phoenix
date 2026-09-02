program Mixed(output);
var
  i : integer;
  x : real;
begin
  i := 7;
  x := 2.0;
  writeln(i + x:12:4);
  writeln(i / 2:12:4);
  writeln(x * i:12:4);
  writeln(i - x:12:4);
  x := i;
  writeln(x:12:4)
end.
