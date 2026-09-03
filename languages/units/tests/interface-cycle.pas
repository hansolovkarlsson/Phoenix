{ fpc -Mtp: Circular unit reference between ug and uf }
unit uf;
interface
uses ug;
  const f_val = 'F';
implementation
end.

unit ug;
interface
uses uf;
  const g_val = 'G';
implementation
end.

program interface_cycle;
uses uf;
begin writeln(f_val); end.
