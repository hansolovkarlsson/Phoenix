{ An interface chain four units deep, ua -> ub -> uc -> ud, and two
  implementation `uses` back to ua. No interface cycle, so fpc -Mtp compiles
  it, and the circularity check must not refuse what it reached through. }
unit ua;
interface
uses ub;
  const a_val = 'A';
implementation
end.

unit ub;
interface
uses uc;
  const b_val = 'B';
implementation
uses ua;
end.

unit uc;
interface
uses ud;
  const c_val = 'C';
implementation
end.

unit ud;
interface
  const d_val = 'D';
implementation
uses ua;
end.

program deep_chain;
uses ua, ub;
begin writeln(a_val); writeln(b_val); end.
