program Routines(output);
var
  n : integer;

function Double(x : integer) : integer;
begin
  Double := x * 2
end;

procedure Bump(var x : integer);
begin
  x := x + 100
end;

function Fact(n : integer) : integer;
begin
  if n <= 1 then Fact := 1 else Fact := n * Fact(n - 1)
end;

begin
  writeln(Double(21));
  n := 1;
  Bump(n);
  writeln(n);
  writeln(Fact(6))
end.
