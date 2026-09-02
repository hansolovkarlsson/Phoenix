animal := object:new.
animal:speak := { "..." }.
dog := animal:new.
dog:speak := { self:via(animal):speak:concat("woof") }.
dog:speak:display.
dog:parent:equals(animal):print.

point := object:new.
point:x := #3.
point:x:print.
point:slots:print.
point:slotAt('x):print.

#45:respondsTo('add):print.
#45:respondsTo('nonesuch):print.
#45:perform('add, #5):print.
"x":isKindOf(string):print.
#1:isKindOf(string):print.
nil:isNil:print.
nil:notNil:print.
#1:equals(#1):print.
#1:equals(1.0):print.
#1:notEquals(#2):print.
