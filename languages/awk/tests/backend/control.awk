# Control flow, which C already has.
BEGIN {
    for (i = 1; i <= 3; i++) printf "%d", i
    print ""
    i = 0; while (i < 3) { printf "%d", i; i++ }
    print ""
    i = 0; do { printf "%d", i; i++ } while (i < 3)
    print ""
    for (i = 0; i < 6; i++) { if (i == 2) continue; if (i == 4) break; printf "%d", i }
    print ""
    if (1 < 2) print "yes"; else print "no"
    if (2 < 1) print "yes"; else print "no"
    print (1 < 2) ? "t" : "f"
    n = 0; for (;;) { n++; if (n > 3) break }
    print n
}
