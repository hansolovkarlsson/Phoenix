program B(output);
type Big = set of 0 .. 200;
var s : Big;
begin
  s := [199];
  if 199 in s then writeln('yes') else writeln('no')
end.
