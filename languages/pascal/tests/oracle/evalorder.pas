program EvalOrder(output);
var n : integer;

function Note(tag : char; result : boolean) : boolean;
begin
  write(tag);
  Note := result
end;

begin
  n := 0;
  if Note('a', false) and Note('b', true) then n := 1;
  writeln(':', n:2);
  if Note('c', true) or Note('d', false) then n := 2;
  writeln(':', n:2)
end.
