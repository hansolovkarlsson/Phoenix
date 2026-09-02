program Mutual(output);
var i : integer;

function IsOdd(n : integer) : boolean; forward;

function IsEven(n : integer) : boolean;
begin
  if n = 0 then IsEven := true else IsEven := IsOdd(n - 1)
end;

function IsOdd;
begin
  if n = 0 then IsOdd := false else IsOdd := IsEven(n - 1)
end;

begin
  for i := 0 to 5 do write(IsEven(i):6);
  writeln
end.
