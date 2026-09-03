a := #5.
a:greaterThan(#3):ifTrue({ "gt":display }).
a:greaterThan(#9):ifFalse({ "not gt":display }).
a:greaterThan(#3):ifElse({ "big" }, { "small" }):display.
i := #0.
{ i:lessThan(#2) }:whileTrue({ i := i:add(#1) }).
i:display.
a:greaterThan(#3):and({ a:lessThan(#9) }):display.
a:greaterThan(#9):or({ a:lessThan(#9) }):display.
