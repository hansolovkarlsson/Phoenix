; Bytes, not characters, and one-based throughout.
"hello":size:print.
"café":size:print.
"hello":at(#1):display.
"hello":at(#5):display.
"a":concat("b"):display.
"a,b,c":split(","):print.
"hello":indexOf("ll"):print.
"hello":indexOf("z"):print.
"hello":copyFrom(#2, #4):display.
"{} of {}":fill([#3, #10]):display.
"  x  ":trim:display.
"MiXeD":asUppercase:display.
"MiXeD":asLowercase:display.
"42":asInteger:print.
"ff":asInteger(#16):print.
"A":asByte:print.
"one":asSymbol:print.
["a", "b"]:join("-"):display.
"a-b":split("-"):join("+"):display.
"abc":lessThan("abd"):print.
