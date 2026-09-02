; **Both ends included, and one-based throughout.** These are the places an
; implementation is off by one and a sampled test agrees with it anyway: a
; range of one element, a range of the whole thing, and the first and last
; positions.

xs := [#10, #20, #30, #40].

; copyFrom includes both ends, so a range of one is a range of one.
xs:copyFrom(#2, #2):print.
xs:copyFrom(#1, #4):print.
xs:copyFrom(#2, #3):print.

"abcde":copyFrom(#3, #3):display.
"abcde":copyFrom(#1, #5):display.

; first and last **clamp** rather than failing, which is what makes them
; different from `at`.
xs:first(#0):print.
xs:first(#2):print.
xs:first(#99):print.
xs:last(#1):print.
xs:last(#99):print.

; `at` does not clamp. One-based at both ends.
xs:at(#1):print.
xs:at(#4):print.
{ xs:at(#0) }:onError({ e | "at(#0) is out of range":display }).
{ xs:at(#5) }:onError({ e | "at(#5) is out of range":display }).
"abc":at(#1):display.
"abc":at(#3):display.

; indexOf answers a one-based position, and nil rather than #0 when absent.
xs:indexOf(#10):print.
xs:indexOf(#40):print.
xs:indexOf(#99):print.
"hello":indexOf("h"):print.
"hello":indexOf("o"):print.
"hello":indexOf("z"):print.
"hello":indexOf("l", #4):print.

; An empty thing is empty rather than an error.
[]:size:print.
"":size:print.
[]:inject(#0, { a, b | a:add(b) }):print.
{ []:removeLast }:onError({ e | "nothing to remove":display }).
