# print and printf, and the variables that punctuate them.
BEGIN {
    print "a", "b", "c"
    OFS = "-"; print "a", "b", "c"
    ORS = "|"; print "x", "y"; ORS = "\n"; print ""
    OFS = " "
    printf "%s|%d|%5.2f|%c|%o|%x|%e\n", "s", 42, 3.14159, 65, 8, 255, 1234.5
    printf "%-6s|%6s|%.3s|\n", "l", "r", "abcdef"
    printf "%d%%\n", 50
    printf "%s\n", 1/3
}
