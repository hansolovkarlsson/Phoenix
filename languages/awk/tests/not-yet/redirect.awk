# Valid awk, and not compiled yet: output to somewhere other than stdout means
# a table of open files and the rules for closing them.
BEGIN { print "x" > "out.txt" }
