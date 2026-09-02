# Valid awk, and not stage one: output to somewhere other than stdout.
BEGIN { print "x" > "out.txt" }
