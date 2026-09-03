{ uses a, b -- and both export x. fpc -Mtp prints "from B". }
unit ua;
interface
  const x = 'from A';
  const only_a = 'A only';
implementation
end.

unit ub;
interface
  const x = 'from B';
  const only_b = 'B only';
implementation
end.

program shadowing;
uses ua, ub;
begin
  writeln(x);
  writeln(ua.x);
  writeln(only_a);
  writeln(only_b);
end.
