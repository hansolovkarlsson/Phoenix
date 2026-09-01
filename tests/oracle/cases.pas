program Cases(output);
var
  i : integer;
begin
  for i := 1 to 6 do
    case i of
      1, 2 : writeln('low');
      3    : writeln('three');
      4, 5 : writeln('high');
      6    : writeln('six')
    end
end.
