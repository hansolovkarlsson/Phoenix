program Control(output);
var
  i, n : integer;
begin
  n := 0;
  for i := 1 to 5 do n := n + i;
  writeln(n);
  for i := 5 downto 1 do n := n - 1;
  writeln(n);
  i := 0;
  while i < 3 do i := i + 1;
  writeln(i);
  repeat i := i + 1 until i >= 6;
  writeln(i);
  if i = 6 then writeln('six') else writeln('not six');
  case i of
    5 : writeln('five');
    6 : writeln('six again');
    7 : writeln('seven')
  end
end.
