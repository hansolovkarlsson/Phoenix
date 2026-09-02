# Records and fields: $0, $n, NF, NR, and a field that looks like a number.
{ print NR, NF, $0 }
{ print $1, $2, $NF, $(NF - 1) }
{ print ($1 == 10), ($1 == "10"), ($2 < $1) }
{ print $0 $1, length($0), length }
END { print "records", NR, "last", $0 }
