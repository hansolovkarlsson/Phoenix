; No implicit conversion, anywhere -- and the one exception.
{ #1:add(1.0) }:onError({ e | "no mixing in add":display }).
{ #1:lessThan(1.0) }:onError({ e | "no mixing in lessThan":display }).
#1:equals(1.0):print.
"1":equals(#1):print.

; A message wanting a block is checked when it is sent, not when it would run.
{ false:and(#45) }:onError({ e | "and wants a block":display }).
{ true:ifElse({ #1 }, #45) }:onError({ e | "ifElse wants blocks":display }).
{ []:collect(#45) }:onError({ e | "collect wants a block":display }).

; Narrowing names its direction: there is no asInteger on a float.
{ 2.7:asInteger }:onError({ e | "no asInteger":display }).
{ "abc":asInteger }:onError({ e | "strict asInteger":display }).
