double := { x | x:mul(#2) }.
double:value(#21):print.

counted := { | n | n := #0. n:inc }.
counted:value:print.

i := #0.
{ i:lessThan(#3) }:whileTrue({ i := i:inc }).
i:print.

j := #0.
{ j := j:inc }:doUntil({ j:greaterOrEqual(#2) }).
j:print.

ticks := #0.
#3:repeat({ ticks := ticks:inc }).
ticks:print.

seen := "".
[#1, #7, #3]:loop({ n | seen := seen:concat(n:asString) }).
seen:display.

{ error:raise("no") }:onError({ e | e:message }):display.
cleaned := false.
r := { #2:add(#2) }:ensure({ cleaned := true }).
r:print.
cleaned:print.
