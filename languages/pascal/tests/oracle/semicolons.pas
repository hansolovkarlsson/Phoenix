program Semicolons(output);
var i : integer;
begin
  i := 1;
  ;
  begin end;
  if i = 1 then ;
  while i < 3 do i := i + 1;
  ;
  writeln(i);
  case i of
    3 : ;
    4 : writeln('four')
  end;
  writeln('done')
end.
