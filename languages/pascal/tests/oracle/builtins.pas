program Builtins(output);
var
  i : integer;
  x : real;
begin
  i := -5;
  writeln(abs(i));
  writeln(sqr(4));
  writeln(odd(7));
  writeln(odd(8));
  writeln(ord('A'));
  writeln(chr(66));
  writeln(succ(3));
  writeln(pred(3));
  x := 2.25;
  writeln(abs(-1.5):8:3);
  writeln(sqrt(x):8:4);
  writeln(round(2.6));
  writeln(trunc(2.6));
  writeln(round(-2.6));
  writeln(trunc(-2.6))
end.
