{ **What this description gets wrong, written down rather than hidden.**

  `A -> B -> C -> A` through interface `uses`. fpc -Mtp refuses it:
  Circular unit reference between uc3 and ua3.

  This accepts it. The check is two units deep -- does the unit I use use me
  back -- and catching a longer one needs the transitive closure of the uses
  graph. Closure needs iteration to a fixpoint, and nothing in this notation
  iterates over *data*: a `%rewrite innermost` reaches a fixpoint over the
  shape of a tree, not over a table.

  It is worth being exact about what that shows. The limit is **graph
  reachability**, which is a well-formedness question forced by separate
  compilation. Resolution itself never needed a walk -- see ../README.md. }
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
