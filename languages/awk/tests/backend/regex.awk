# Patterns, ~ and !~, and the builtins that take one.
/^two/ { print "pattern:", $1 }
$2 ~ /b/ { print "tilde:", $2 }
$2 !~ /b/ { print "not-tilde:", $2 }
{
    t = $0
    n = gsub(/[aeiou]/, "<&>", t); print n, t
    u = $0; sub(/^./, "*", u); print u
    print match($0, /[0-9]+/), RSTART, RLENGTH
    m = split($0, parts, " +"); print m, parts[1], parts[m]
    print ($1 ~ "^" "o")
}
