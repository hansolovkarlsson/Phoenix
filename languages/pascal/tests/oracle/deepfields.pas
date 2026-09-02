program DeepFields(output);
type
  Inner = record ch : char; n : integer end;
  Row   = array [1 .. 2] of Inner;
  Outer = record items : Row; tag : char end;
var
  o : Outer;
begin
  o.items[1].ch := 'p';
  o.items[1].n := 10;
  o.items[2].ch := 'q';
  o.items[2].n := 20;
  o.tag := 'T';
  writeln(o.items[1].ch);
  writeln(o.items[2].n);
  writeln(o.tag);
  with o do writeln(items[2].ch)
end.
