{ A program in the subset examples/pascal-c.phx compiles: constants, subranges,
  arrays with written bounds, records, value and var parameters, if, while,
  repeat, for, and writeln. }
program Primes(output);

const
  Limit = 30;

type
  Index  = 1 .. Limit;
  Flags  = array [1 .. Limit] of boolean;
  Result = record
             count : integer;
             last  : integer
           end;

var
  sieve : Flags;
  found : Result;
  i     : Index;

procedure Clear(var f : Flags);
var
  k : integer;
begin
  for k := 1 to Limit do
    f[k] := true
end;

function Gcd(u, v : integer) : integer;
var
  t : integer;
begin
  while v <> 0 do
    begin
      t := u mod v;
      u := v;
      v := t
    end;
  Gcd := u
end;

procedure Sift(var f : Flags; var r : Result);
var
  p, q : integer;
begin
  r.count := 0;
  r.last := 0;
  p := 2;
  while p <= Limit do
    begin
      if f[p] then
        begin
          r.count := r.count + 1;
          r.last := p;
          q := p + p;
          while q <= Limit do
            begin
              f[q] := false;
              q := q + p
            end
        end;
      p := p + 1
    end
end;

begin
  Clear(sieve);
  sieve[1] := false;
  Sift(sieve, found);

  writeln(found.count);
  writeln(found.last);
  writeln(Gcd(1071, 462));

  i := 1;
  repeat
    if sieve[i] then
      writeln(i);
    i := i + 1
  until i > 12
end.
