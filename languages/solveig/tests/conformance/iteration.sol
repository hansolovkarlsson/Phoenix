; **How many times, exactly.** A loop that counts to its end inclusive, a body
; that runs before its condition, and the zero cases -- which is where an
; implementation is off by one and every ordinary program still works.

; `loop` counts to its end **inclusive**, so [#1, #3] is three numbers.
seen := "".
[#1, #3]:loop({ n | seen := seen:concat(n:asString) }).
seen:display.

; A range of one is one iteration, not none.
seen := "".
[#2, #2]:loop({ n | seen := seen:concat(n:asString) }).
seen:display.

; A range that has already passed its end is no iterations.
seen := "x".
[#3, #1]:loop({ n | seen := seen:concat(n:asString) }).
seen:display.

; With a step, still inclusive, and the end is reached only if the step lands
; on it.
seen := "".
[#1, #7, #3]:loop({ n | seen := seen:concat(n:asString):concat(" ") }).
seen:display.
seen := "".
[#1, #6, #3]:loop({ n | seen := seen:concat(n:asString):concat(" ") }).
seen:display.

; A negative step counts down, inclusive at the bottom.
seen := "".
[#3, #1, #-1]:loop({ n | seen := seen:concat(n:asString):concat(" ") }).
seen:display.

; `repeat` of nought runs nothing.
ticks := #0.
#0:repeat({ ticks := ticks:inc }).
ticks:print.
#1:repeat({ ticks := ticks:inc }).
ticks:print.

; `whileTrue` tests first, so a condition false at the start runs nothing.
runs := #0.
{ false }:whileTrue({ runs := runs:inc }).
runs:print.

; `doUntil` runs its body **first**, so it always runs at least once -- even
; when the condition is already true.
runs := #0.
{ runs := runs:inc }:doUntil({ true }).
runs:print.

; And `do` over an empty array is no iterations rather than one.
runs := #0.
[]:do({ x | runs := runs:inc }).
runs:print.
