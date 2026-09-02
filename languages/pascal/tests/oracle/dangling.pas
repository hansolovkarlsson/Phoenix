program Dangling(output);
var i : integer;
begin
  for i := 1 to 3 do
    if i > 1 then
      if i > 2 then writeln('big')
      else writeln('middle')
    else writeln('small')
end.
