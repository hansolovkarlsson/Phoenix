# `cmd | getline` and `cmd | getline var` -- the two forms that need `|` to be
# an expression operator, and the rung's place in the ladder.
#
# Every line here was checked against /usr/bin/awk before the grammar was
# written: the pipe is looser than concatenation, tighter than a relation, and
# a left fold. The last two are the ones a reading of the ladder would get
# wrong.
BEGIN {
	"echo hello" | getline greeting
	print "1:", greeting

	# No variable: it sets $0 and NF, like a read from the input.
	"echo one two three" | getline
	print "2:", NF, $2

	# Looser than concatenation, so the command is the whole of it.
	"ec" "ho joined" | getline j
	print "3:", j

	# It answers 1, 0 or -1, the way every other getline does.
	print "4:", ("echo yes" | getline y), y

	# Tighter than a relation: this is (pipe) > 5, which is 1 > 5.
	r = "echo hi" | getline z > 5
	print "5:", r, z

	# An lvalue, not just a name.
	"echo subscripted" | getline arr["k"]
	print "6:", arr["k"]

	# The idiom it is all for.
	while (("printf 'a\nb\nc\n'" | getline ln) > 0) n++
	print "7:", n

	# And in a print argument `|` is still the redirect, which is why the
	# print ladder does not have this rung: the parentheses are what say so.
	print "8:", ("echo parenthesised" | getline p), p
}
