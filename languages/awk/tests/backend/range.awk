# A rule with a memory. `/b/,/d/` runs from the first match to the next, and
# `/x/,/x/` matches one line because the second pattern is tried on the same
# record.
/b/, /d/ { print "range:", $0 }
/c/, /c/ { print "one:", $0 }
{ print NR, FNR, (FILENAME != "") }
