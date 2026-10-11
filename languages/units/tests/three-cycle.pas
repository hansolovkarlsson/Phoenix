{ fpc -Mtp: Circular unit reference between ub3 and ua3 }
{ `A -> B -> C -> A` through interface `uses`, three units deep.

  Until 2026-10-10 this file was in `divergent/`: the check was two units
  deep, and catching a longer cycle needs the transitive closure of the uses
  graph, which the description had no way to iterate to. The `reach` pass
  in units.phx is that iteration, run by the driver `until` its table
  settles. fpc stops at the first `uses` it finds circular, here ub3's, and
  this refuses all three, ub3's among them in the same words. }
unit ua3;
interface
uses uc3;
  const a_val = 'A';
implementation
end.

unit ub3;
interface
uses ua3;
  const b_val = 'B';
implementation
end.

unit uc3;
interface
uses ub3;
  const c_val = 'C';
implementation
end.

program three_cycle;
uses ua3;
begin writeln(a_val); end.
