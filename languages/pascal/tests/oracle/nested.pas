program Nested(output);
type
  Inner = record a, b : integer end;
  Outer = record p : Inner; q : integer end;
var
  o : Outer;
begin
  o.p.a := 1; o.p.b := 2; o.q := 3;
  writeln(o.p.a + o.p.b + o.q);
  with o do
    begin
      writeln(q);
      with p do writeln(a + b)
    end
end.
