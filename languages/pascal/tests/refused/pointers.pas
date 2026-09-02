program P(output);
type
  Link = ^Cell;
  Cell = record value : integer end;
var
  p : Link;
begin
  new(p);
  p^.value := 1;
  writeln(p^.value);
  dispose(p)
end.
