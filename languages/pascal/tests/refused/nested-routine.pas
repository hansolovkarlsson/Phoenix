program N(output);
procedure Outer;
  procedure Inner;
  begin writeln(1) end;
begin Inner end;
begin Outer end.
