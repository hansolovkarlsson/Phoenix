; Integers: arithmetic that traps, division that floors.
#45:print.
#7:add(#5):print.
#7:sub(#9):print.
#6:mul(#7):print.

; Floored, not truncated -- the sign of the remainder follows the divisor.
#7:div(#2):print.
#-7:div(#2):print.
#7:div(#-2):print.
#7:mod(#3):print.
#-7:mod(#3):print.

#5:inc:print.
#5:dec:print.
#-5:abs:print.
#5:negated:print.

#255:asBase(#16):display.
#65:asCharacter:display.
#5:asFloat:print.
#42:asString:display.

; Overflow is an error rather than a wrap.
{ #9223372036854775807:add(#1) }:onError({ e | "trapped":display }).
{ #1:div(#0) }:onError({ e | "no division by zero":display }).
