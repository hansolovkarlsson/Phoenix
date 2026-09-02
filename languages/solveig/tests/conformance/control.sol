#3:greaterThan(#2):ifTrue({ "yes":display }).
#3:lessThan(#2):ifFalse({ "not less":display }).
#5:greaterThan(#9):ifElse({ "big" }, { "small" }):display.
true:and({ false }):print.
false:and({ true }):print.
true:or({ false }):print.
true:not:print.
[#1, #3]:loop({ n | n:print }).
[#1, #5, #2]:loop({ n | n:print }).
[#3, #1, #-1]:loop({ n | n:print }).
