; **There is no `asInteger` on a float**, because there are four answers and a
; name that did not say which would be picking one silently. This is the whole
; table, in the order truncated / rounded / floor / ceiling.
;
;              1.5   -1.5    2.5
;  truncated    1     -1      2
;  rounded      2     -2      3
;  floor        1     -2      2
;  ceiling      2     -1      3
;
; `truncated` goes toward zero and `floor` goes down, which is the pair that
; differs only on a negative. `rounded` goes away from zero at a half, which is
; the pair that differs only at one.

1.5:truncated:print.
-1.5:truncated:print.
2.5:truncated:print.

1.5:rounded:print.
-1.5:rounded:print.
2.5:rounded:print.

1.5:floor:print.
-1.5:floor:print.
2.5:floor:print.

1.5:ceiling:print.
-1.5:ceiling:print.
2.5:ceiling:print.

; A half goes away from zero in both directions, not toward even.
-2.5:rounded:print.
0.5:rounded:print.
-0.5:rounded:print.

; And the name that does not say which is not there at all.
{ 1.5:asInteger }:onError({ e | e:message:display }).
