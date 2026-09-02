program Recursion(output);
var i : integer;

function Fib(n : integer) : integer;
begin
  if n < 2 then Fib := n else Fib := Fib(n - 1) + Fib(n - 2)
end;

function Depth(n : integer) : integer;
begin
  if n = 0 then Depth := 0 else Depth := 1 + Depth(n - 1)
end;

begin
  for i := 0 to 10 do write(Fib(i):4);
  writeln;
  writeln(Depth(500))
end.
