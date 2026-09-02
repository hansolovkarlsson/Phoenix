# print and printf, and the redirection that makes `>` ambiguous.
BEGIN {
    print "plain"
    print "a", "b", "c"
    printf "%s|%d|%5.2f|%c\n", "s", 42, 3.14159, 65
    printf "%-5s|%5s|\n", "l", "r"
    print "to a file" > "awk-out.txt"
    print "and again" >> "awk-out.txt"
    close("awk-out.txt")
    print (1 > 2), (2 > 1)
}
