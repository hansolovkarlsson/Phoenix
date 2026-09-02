program CharArray(output);
type Three = packed array [1 .. 3] of char;
var a : Three;
begin
  a := 'xyz';
  writeln(a[1])
end.
