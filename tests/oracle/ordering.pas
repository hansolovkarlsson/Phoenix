program Ordering(output);
type
  Grade = (Poor, Fair, Good);
var
  g, h : Grade;
begin
  g := Poor; h := Good;
  writeln(g < h);
  writeln(g = h);
  writeln(ord(succ(g)));
  writeln(ord(pred(h)));
  for g := Poor to Good do write(ord(g):2);
  writeln
end.
