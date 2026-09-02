program ForLoops(output);
type
  Colour = (Red, Green, Blue);
var
  c : Colour;
  ch : char;
  i : integer;
begin
  for c := Red to Blue do write(ord(c):2);
  writeln;
  for ch := 'a' to 'e' do write(ch);
  writeln;
  for i := 3 downto 1 do write(i:2);
  writeln
end.
