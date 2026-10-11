{ ua's implementation uses uc and then ub, and ub and uc use each other in
  theirs. fpc -Mtp initialises ub, uc, ua: the walk from the program enters
  ua, then uc, then ub from uc, finds uc already entered, and finishes ub
  first. Not the order the units are written in, and not the order ua
  names them. }
unit ua;
interface
  const ua_v = 'ua';
implementation
uses uc, ub;
begin
  writeln(ua_v);
end.

unit ub;
interface
  const ub_v = 'ub';
implementation
uses uc;
begin
  writeln(ub_v);
end.

unit uc;
interface
  const uc_v = 'uc';
implementation
uses ub;
begin
  writeln(uc_v);
end.

program init_order;
uses ua;
begin writeln(ua_v); end.
