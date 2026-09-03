{ **The second thing this description gets wrong, and it is not resolution.**

  `ud` and `ue` use each other in their implementations, which is legal Turbo
  Pascal. Every name resolves the same here as it does under fpc -- the cycle
  costs this description nothing at all, because visibility does not compose
  and so resolving a `uses` is one lookup in a table pass one already built,
  not a walk. There is no traversal for a cycle to be a cycle in.

  What differs is the **order the initialisation sections run in**. fpc prints
  D, E, D: it initialises a unit after the units it depends on, which is a
  topological order of the uses graph. This prints E, D, D -- the order the
  units are written in.

  That order *is* graph-shaped, and this notation cannot compute it: a
  topological sort needs iteration to a fixpoint over data, and nothing here
  iterates over data. It is worth separating from the question this
  description was written to answer, because it is a different one: not *what
  does this name mean* but *in what order do these run*. See ../README.md. }
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
