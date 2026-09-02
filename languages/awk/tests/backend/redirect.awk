# Output that does not go to stdout, and the table of open files behind it.
BEGIN {
    print "first" > "r-out.txt"
    print "second" > "r-out.txt"
    print "appended" >> "r-out.txt"
    close("r-out.txt")
    printf "%s\n", "piped" | "cat"
    close("cat")
    system("cat r-out.txt")
    print "status", system("true")
}
