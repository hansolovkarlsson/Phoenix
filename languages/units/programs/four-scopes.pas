{ Which of the four scopes wins, inside a unit's initialisation section.
  fpc -Mtp prints "I interface" -- a unit's own interface shadows what its
  implementation uses, which is the one a reading of the rules gets wrong. }
unit ub;
interface
  const x = 'from B';
implementation
end.

unit ui;
interface
  const x = 'I interface';
implementation
uses ub;
begin
  writeln(x);
end.

program four_scopes;
uses ui;
begin
  writeln(x);
end.
