program Sets(output);
type
  Digit = 0 .. 9;
var
  s, t : set of Digit;
  i : integer;
begin
  s := [1, 3, 5];
  t := [3, 4];
  if 3 in s then writeln('three');
  if 2 in s then writeln('two') else writeln('no two');
  for i := 0 to 9 do
    if i in s then write(i:2);
  writeln
end.
