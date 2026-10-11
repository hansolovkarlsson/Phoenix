{ `ud` and `ue` use each other in their implementations, which is legal
  Turbo Pascal, and fpc -Mtp prints D, E, D: ue is initialised first,
  because the walk from the program enters ud, then ue from ud's
  implementation, and finds ud already entered. Until 2026-10-10 this file
  was in `divergent/`, and the description printed E, D, D, the order the
  units are written in. }
unit ud;
interface
  const d_val = 'D';
implementation
uses ue;
begin
  writeln(e_val);
end.

unit ue;
interface
  const e_val = 'E';
implementation
uses ud;
begin
  writeln(d_val);
end.

program circular_impl;
uses ud;
begin
  writeln(d_val);
end.
