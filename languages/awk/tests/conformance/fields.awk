# Records, fields, and the patterns that select them.
{ print NR, NF, $1, $NF }
$2 == "b" { print "matched b" }
/three/ { print "matched three" }
/^two/, /^four/ { print "in range:", $1 }
END { print "records", NR }
