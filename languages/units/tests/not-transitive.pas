{ fpc -Mtp: Identifier not found "only_b" }
{ Visibility does not compose. `uc`'s interface uses `ub`, but a program that
  uses `uc` does not see `ub`'s names -- fpc: Identifier not found "only_b".
  That is the one place a scope graph would have had to be walked, and is not. }
unit ub;
interface
  const only_b = 'B only';
implementation
end.

unit uc;
interface
uses ub;
  const c_val = 'C';
implementation
end.

program not_transitive;
uses uc;
begin
  writeln(c_val);
  writeln(only_b);
end.
