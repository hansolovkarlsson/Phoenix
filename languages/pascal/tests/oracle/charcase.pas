program CharCase(output);
var c : char;
begin
  for c := 'a' to 'd' do
    case c of
      'a' : writeln('first');
      'b', 'c' : writeln('middle');
      'd' : writeln('last')
    end
end.
