; One-based, and `add` answers the array so it chains.
xs := [#4, #1, #3].
xs:size:print.
xs:at(#1):print.
xs:indexOf(#3):print.
xs:indexOf(#9):print.
xs:copyFrom(#1, #2):print.
xs:first(#9):print.
xs:last(#2):print.
xs:sorted:print.
xs:collect({ x | x:mul(#2) }):print.
xs:select({ x | x:greaterThan(#2) }):print.
xs:inject(#0, { a, b | a:add(b) }):print.
xs:add(#9):size:print.
xs:removeLast:print.
["a", "b", "c"]:join(","):display.

; `join` is strict: it wants strings, and says so rather than converting.
{ [#1, #2]:join(",") }:onError({ e | "join wants strings":display }).
array:new:size:print.
array:of(#1, #2):print.
{ [#1]:at(#5) }:onError({ e | "out of range":display }).
