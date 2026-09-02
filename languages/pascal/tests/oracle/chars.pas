program Chars(output);
var
  c, d : char;
begin
  c := 'a'; d := 'z';
  writeln(c);
  writeln(c < d);
  writeln(ord(d) - ord(c));
  writeln(chr(ord(c) + 1));
  writeln(succ(c));
  writeln(pred(d));
  if c <> d then writeln('differ')
end.
