program Boundaries(output);
type
  Colour = (Red, Green, Blue);
var
  c : Colour;
  ch : char;
begin
  c := Blue;
  writeln(ord(c));
  c := Red;
  writeln(ord(c));
  ch := chr(0);
  writeln(ord(ch));
  ch := chr(127);
  writeln(ord(ch));
  writeln(ord('~'));
  writeln(chr(32) = ' ')
end.
