program Enums(output);
type
  Colour = (Red, Green, Blue);
var
  c : Colour;
begin
  c := Green;
  writeln(ord(c));
  writeln(ord(Red));
  writeln(ord(Blue));
  c := succ(Red);
  writeln(ord(c));
  if c = Green then writeln('green');
  case c of
    Red   : writeln('r');
    Green : writeln('g');
    Blue  : writeln('b')
  end
end.
